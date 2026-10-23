const sql = require('mssql');
require('dotenv').config();

const serverString = process.env.DB_SERVER || '';
const serverParts = serverString.split('\\');

console.log('Server Parts:', serverParts);

const config = {
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    server: 'localhost', 
    database: process.env.DB_DATABASE,
    options: {
        encrypt: false,
        trustServerCertificate: true,
        instanceName: 'SQLEXPRESS'
    },
    connectionTimeout: 5000 
};

console.log('Attempting to connect with config:', { ...config, password: '****' });

sql.connect(config).then(pool => {
    console.log('SUCCESS: Connected to MSSQL');
    return pool.query('SELECT @@VERSION as version');
}).then(result => {
    console.log('SQL Version:', result.recordset[0].version);
    process.exit(0);
}).catch(err => {
    console.error('FAILURE: Connection failed');
    console.error(err);
    process.exit(1);
});
