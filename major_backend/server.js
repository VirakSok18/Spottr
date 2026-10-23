const express = require('express');
const cors = require('cors');
require('dotenv').config();

const userRoutes = require('./routes/userRoutes');
const workoutRoutes = require('./routes/workoutRoutes');
const postRoutes = require('./routes/postRoutes');

const app = express();
const http = require('http');
const server = http.createServer(app);
const { Server } = require("socket.io");
const io = new Server(server, {
    cors: {
        origin: "*", // Allow all connections (for simplicity in development)
        methods: ["GET", "POST"]
    }
});
app.set('io', io);

const PORT = process.env.PORT || 5000;

app.use(cors());

// Special handling for Stripe webhook raw body (MUST be before express.json)
app.use('/api/payments/webhook', express.raw({ type: 'application/json', limit: '10mb' }));

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ limit: '10mb', extended: true }));

// Socket Handler
require('./socket/socketHandler')(io);

// Routes
app.use('/api/users', userRoutes);
app.use('/api/workouts', workoutRoutes);
app.use('/api/posts', postRoutes);
app.use('/api/chat', require('./routes/chatRoutes'));
app.use('/api/ai-coach', require('./routes/aiCoachRoutes'));
app.use('/api/notifications', require('./routes/notificationRoutes'));

// Payment routes
app.use('/api/payments', require('./routes/paymentRoutes'));

app.get('/health', (req, res) => {
    res.status(200).send('Backend is healthy');
});

server.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});
