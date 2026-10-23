const express = require('express');
const router = express.Router();
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const { poolPromise, sql } = require('../config/db');
const authMiddleware = require('../middleware/auth');

// Create a Stripe Checkout Session
router.post('/create-checkout-session', authMiddleware, async (req, res) => {
    const { planType } = req.body; // 'monthly', 'yearly', 'lifetime'
    const { uid, email } = req.user;

    let priceData;
    switch (planType) {
        case 'monthly':
            priceData = {
                currency: 'usd',
                product_data: { name: 'Premium Monthly' },
                unit_amount: 299, // $2.99
                recurring: { interval: 'month' }
            };
            break;
        case 'yearly':
            priceData = {
                currency: 'usd',
                product_data: { name: 'Premium Yearly' },
                unit_amount: 1999, // $19.99
                recurring: { interval: 'year' }
            };
            break;
        case 'lifetime':
            priceData = {
                currency: 'usd',
                product_data: { name: 'Premium Lifetime' },
                unit_amount: 4999, // $49.99
            };
            break;
        default:
            return res.status(400).json({ error: 'Invalid plan type' });
    }

    try {
        const session = await stripe.checkout.sessions.create({
            payment_method_types: ['card'],
            line_items: [{
                price_data: priceData,
                quantity: 1,
            }],
            mode: planType === 'lifetime' ? 'payment' : 'subscription',
            success_url: `spottr://payment-success?session_id={CHECKOUT_SESSION_ID}`,
            cancel_url: `spottr://payment-cancelled`,
            customer_email: email,
            metadata: {
                firebaseUid: uid,
                planType: planType
            },
        });

        res.json({ url: session.url });
    } catch (err) {
        console.error('Stripe Session Error:', err);
        res.status(500).json({ error: 'Failed to create checkout session' });
    }
});

// Generate Stripe Billing Portal session
router.get('/billing-portal', authMiddleware, async (req, res) => {
    try {
        const { uid } = req.user;
        const pool = await poolPromise;
        const result = await pool.request()
            .input('uid', sql.NVARCHAR, uid)
            .query('SELECT stripeCustomerId FROM Users WHERE firebaseUid = @uid');

        const customerId = result.recordset[0]?.stripeCustomerId;

        if (!customerId) {
            return res.status(400).json({ error: 'No active subscription found' });
        }

        const session = await stripe.billingPortal.sessions.create({
            customer: customerId,
            return_url: `spottr://profile`,
        });

        res.json({ url: session.url });
    } catch (err) {
        console.error('Stripe Portal Error:', err);
        res.status(500).json({ error: 'Failed to create portal session' });
    }
});

// Get current subscription details
router.get('/subscription-details', authMiddleware, async (req, res) => {
    try {
        const { uid } = req.user;
        const pool = await poolPromise;
        const result = await pool.request()
            .input('uid', sql.NVARCHAR, uid)
            .query('SELECT stripeSubscriptionId, planType FROM Users WHERE firebaseUid = @uid');

        const subscriptionId = result.recordset[0]?.stripeSubscriptionId;
        const dbPlanType = result.recordset[0]?.planType || 'Premium';

        if (!subscriptionId) {
            return res.json({
                status: 'active', // Fallback for lifetime or manual override
                planName: dbPlanType.toUpperCase(),
                renewalDate: null,
                cardLast4: null,
                cardBrand: null,
            });
        }

        const subscription = await stripe.subscriptions.retrieve(subscriptionId, {
            expand: ['default_payment_method'],
        });

        let cardLast4 = null;
        let cardBrand = null;

        if (subscription.default_payment_method && typeof subscription.default_payment_method !== 'string') {
            cardLast4 = subscription.default_payment_method.card.last4;
            cardBrand = subscription.default_payment_method.card.brand;
        }

        let renewalDate = null;
        const currentPeriodEnd = subscription.current_period_end
            || (subscription.items?.data?.length > 0 ? subscription.items.data[0].current_period_end : null)
            || subscription.cancel_at;

        if (currentPeriodEnd) {
            const timestamp = parseInt(currentPeriodEnd, 10);
            if (!isNaN(timestamp)) {
                renewalDate = new Date(timestamp * 1000).toISOString();
            }
        }

        res.json({
            status: subscription.status,
            planName: dbPlanType.toUpperCase(),
            isCanceling: subscription.cancel_at_period_end || !!subscription.cancel_at,
            renewalDate,
            cardLast4,
            cardBrand,
        });

    } catch (err) {
        console.error('Stripe Subscription Fetch Error:', err);
        res.status(500).json({ error: 'Failed to fetch subscription details' });
    }
});

// Stripe Webhook Helper (Raw Middleware is applied in server.js for this route)
router.post('/webhook', async (req, res) => {
    const sig = req.headers['stripe-signature'];
    let event;

    try {
        // req.body here MUST be the raw buffer
        event = stripe.webhooks.constructEvent(
            req.body,
            sig,
            process.env.STRIPE_WEBHOOK_SECRET
        );
    } catch (err) {
        console.error('Webhook Signature Error:', err.message);
        return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    // Handle the event
    try {
        const pool = await poolPromise;

        if (event.type === 'checkout.session.completed') {
            const session = event.data.object;
            const firebaseUid = session.metadata.firebaseUid;
            const planType = session.metadata.planType;
            const customerId = session.customer;
            const subscriptionId = session.subscription;

            console.log(`Payment successful for user: ${firebaseUid}, Plan: ${planType}`);

            await pool.request()
                .input('uid', sql.NVARCHAR, firebaseUid)
                .input('planType', sql.NVARCHAR, planType)
                .input('customerId', sql.NVARCHAR, customerId)
                .input('subscriptionId', sql.NVARCHAR, subscriptionId)
                .query(`
                    UPDATE Users 
                    SET isPremium = 1, 
                        planType = @planType, 
                        stripeCustomerId = @customerId, 
                        stripeSubscriptionId = @subscriptionId 
                    WHERE firebaseUid = @uid
                `);

            console.log(`User ${firebaseUid} is now Premium!`);
        }
        else if (event.type === 'customer.subscription.updated') {
            const subscription = event.data.object;
            const customerId = subscription.customer;
            const status = subscription.status;

            console.log(`Subscription updated for customer ${customerId}, status: ${status}`);

            // Just in case they got a completely new plan ID (upgrade/downgrade)
            // Note: Determining the new planType string requires fetching from the product, but for now we keep the existing or rely on the frontend checkout for upgrades.

            if (status !== 'active' && status !== 'trialing') {
                // E.g., past_due, canceled, unpaid
                await pool.request()
                    .input('customerId', sql.NVARCHAR, customerId)
                    .query(`
                        UPDATE Users 
                        SET isPremium = 0, stripeSubscriptionId = NULL, planType = NULL 
                        WHERE stripeCustomerId = @customerId
                    `);
            } else {
                // Make sure they are active if they renewed
                await pool.request()
                    .input('customerId', sql.NVARCHAR, customerId)
                    .query(`
                        UPDATE Users 
                        SET isPremium = 1 
                        WHERE stripeCustomerId = @customerId
                    `);
            }
        }
        else if (event.type === 'customer.subscription.deleted') {
            const subscription = event.data.object;
            const customerId = subscription.customer;

            console.log(`Subscription deleted for customer ${customerId}`);

            await pool.request()
                .input('customerId', sql.NVARCHAR, customerId)
                .query(`
                    UPDATE Users 
                    SET isPremium = 0, stripeSubscriptionId = NULL, planType = NULL 
                    WHERE stripeCustomerId = @customerId
                `);
        }
    } catch (dbErr) {
        console.error('Database Update Error in Webhook:', dbErr);
    }

    res.json({ received: true });
});

module.exports = router;
