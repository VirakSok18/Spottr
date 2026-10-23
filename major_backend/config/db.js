const sql = require('mssql');
require('dotenv').config();

const serverString = process.env.DB_SERVER || 'localhost';
const serverParts = serverString.split('\\');

const config = {
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    server: serverParts[0],
    port: parseInt(process.env.DB_PORT) || 1433,
    database: process.env.DB_DATABASE,
    options: {
        encrypt: process.env.DB_ENCRYPT === 'true' || (process.env.DB_SERVER && !process.env.DB_SERVER.includes('localhost') && !process.env.DB_SERVER.includes('127.0.0.1')),
        trustServerCertificate: true,
        instanceName: serverParts[1] 
    }
};

const poolPromise = new sql.ConnectionPool(config)
    .connect()
    .then(pool => {
        console.log('Connected to MSSQL');
        return pool;
    })
    .catch(err => {
        console.error('Database Connection Failed! Bad Config: ', err);
        throw err;
    });

module.exports = {
    sql,
    poolPromise
};
