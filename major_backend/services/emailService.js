const nodemailer = require('nodemailer');
require('dotenv').config();

const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS, // This must be a 16-character App Password
    },
});

const sendOTPEmail = async (email, otp) => {
    try {
        const mailOptions = {
            from: `"Spottr" <${process.env.EMAIL_USER}>`,
            to: email,
            subject: 'Your Spottr Password Reset Code',
            html: `
                <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 20px; border: 1px solid #eee; border-radius: 10px;">
                    <h2 style="color: #B497FF; text-align: center;">Reset Your Password</h2>
                    <p>Hello,</p>
                    <p>You requested to reset your password for your Spottr account. Use the code below to complete the process. This code will expire in 15 minutes.</p>
                    <div style="text-align: center; margin: 30px 0;">
                        <span style="font-size: 32px; font-weight: bold; letter-spacing: 5px; color: #B497FF; background: #f9f9f9; padding: 10px 20px; border-radius: 5px; border: 1px dashed #B497FF;">
                            ${otp}
                        </span>
                    </div>
                    <p>If you didn't request this, you can safely ignore this email.</p>
                    <p>Stay active,<br>The Spottr Team</p>
                </div>
            `,
        };

        const info = await transporter.sendMail(mailOptions);
        console.log('Email sent:', info.messageId);
        return { success: true, data: info };
    } catch (err) {
        console.error('Email Service (Nodemailer) Error:', err);
        return { success: false, error: err.message };
    }
};

const sendVerificationEmail = async (email, otp) => {
    try {
        const mailOptions = {
            from: `"Spottr" <${process.env.EMAIL_USER}>`,
            to: email,
            subject: 'Spottr Account Verification Code',
            html: `
                <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 20px; border: 1px solid #eee; border-radius: 10px;">
                    <h2 style="color: #B497FF; text-align: center;">Verify Your Account</h2>
                    <p>Hello,</p>
                    <p>Welcome to Spottr! Use the code below to verify your email address and complete your registration. This code will expire in 10 minutes.</p>
                    <div style="text-align: center; margin: 30px 0;">
                        <span style="font-size: 32px; font-weight: bold; letter-spacing: 5px; color: #B497FF; background: #f9f9f9; padding: 10px 20px; border-radius: 5px; border: 1px dashed #B497FF;">
                            ${otp}
                        </span>
                    </div>
                    <p>If you didn't attempt to sign up, you can safely ignore this email.</p>
                    <p>Stay active,<br>The Spottr Team</p>
                </div>
            `,
        };

        const info = await transporter.sendMail(mailOptions);
        console.log('Verification email sent:', info.messageId);
        return { success: true, data: info };
    } catch (err) {
        console.error('Email Service Error:', err);
        return { success: false, error: err.message };
    }
};

module.exports = {
    sendOTPEmail,
    sendVerificationEmail,
};
