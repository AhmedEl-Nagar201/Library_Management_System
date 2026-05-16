const express = require('express');
const mysql = require('mysql2/promise');
const cors = require('cors');
const bodyParser = require('body-parser');
const path = require('path');

const app = express();
const PORT = 3000;

app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));
app.use(express.static(path.join(__dirname)));

// Database configuration from local.txt
const dbConfig = {
    host: '127.0.0.1',
    user: 'root',
    password: 'admin',
    database: 'library_management_system'
};

let pool;

async function initDB() {
    try {
        pool = mysql.createPool(dbConfig);
        const connection = await pool.getConnection();
        console.log('Connected to MySQL database successfully!');
        connection.release();
    } catch (error) {
        console.error('Database connection failed:', error.message);
        console.log('Make sure MySQL is running and database exists');
    }
}

initDB();

// Helper function to execute queries
async function query(sql, params = []) {
    if (!pool) throw new Error('Database not connected');
    const [rows] = await pool.execute(sql, params);
    return rows;
}

// Auth endpoints
app.post('/api/login', async (req, res) => {
    try {
        const { email, password } = req.body;
        const users = await query(
            'SELECT u.user_id, u.first_name, u.last_name, u.email, u.role, u.password_hash FROM users u WHERE u.email = ? AND u.is_active = 1',
            [email]
        );
        
        if (users.length === 0) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }
        
        const user = users[0];
        // Simple password comparison (in production use bcrypt)
        if (user.password_hash !== password) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }
        
        res.json({
            user_id: user.user_id,
            first_name: user.first_name,
            last_name: user.last_name,
            email: user.email,
            role: user.role
        });
    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({ error: error.message });
    }
});

app.get('/api/users/:id', async (req, res) => {
    try {
        const users = await query('SELECT * FROM users WHERE user_id = ?', [req.params.id]);
        if (users.length === 0) {
            return res.status(404).json({ error: 'User not found' });
        }
        res.json(users[0]);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Generic CRUD endpoints for each table

// Membership Tiers
app.get('/api/membership-tiers', async (req, res) => {
    try {
        const rows = await query('SELECT * FROM membership_tiers ORDER BY tier_id');
        res.json(rows);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.post('/api/membership-tiers', async (req, res) => {
    try {
        const { tier_name, max_books, loan_duration_days, fine_per_day } = req.body;
        const result = await query(
            'INSERT INTO membership_tiers (tier_name, max_books, loan_duration_days, fine_per_day) VALUES (?, ?, ?, ?)',
            [tier_name, max_books, loan_duration_days, fine_per_day]
        );
        res.json({ id: result.insertId, ...req.body });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.put('/api/membership-tiers/:id', async (req, res) => {
    try {
        const { tier_name, max_books, loan_duration_days, fine_per_day } = req.body;
        await query(
            'UPDATE membership_tiers SET tier_name=?, max_books=?, loan_duration_days=?, fine_per_day=? WHERE tier_id=?',
            [tier_name, max_books, loan_duration_days, fine_per_day, req.params.id]
        );
        res.json({ id: req.params.id, ...req.body });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.delete('/api/membership-tiers/:id', async (req, res) => {
    try {
        await query('DELETE FROM membership_tiers WHERE tier_id = ?', [req.params.id]);
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Users
app.get('/api/users', async (req, res) => {
    try {
        const rows = await query(`
            SELECT u.*, t.tier_name 
            FROM users u 
            LEFT JOIN membership_tiers t ON u.tier_id = t.tier_id 
            ORDER BY u.user_id
        `);
        res.json(rows);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.post('/api/users', async (req, res) => {
    try {
        const { national_id, first_name, last_name, email, street_address, city, state_province, postal_code, country, role, tier_id, is_active, password_hash } = req.body;
        const result = await query(
            `INSERT INTO users (national_id, first_name, last_name, email, street_address, city, state_province, postal_code, country, role, tier_id, is_active, password_hash) 
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            [national_id, first_name, last_name, email, street_address, city, state_province, postal_code, country, role, tier_id, is_active, password_hash || 'default123']
        );
        res.json({ id: result.insertId, ...req.body });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.put('/api/users/:id', async (req, res) => {
    try {
        const { national_id, first_name, last_name, email, street_address, city, state_province, postal_code, country, role, tier_id, is_active } = req.body;
        await query(
            `UPDATE users SET national_id=?, first_name=?, last_name=?, email=?, street_address=?, city=?, state_province=?, postal_code=?, country=?, role=?, tier_id=?, is_active=? WHERE user_id=?`,
            [national_id, first_name, last_name, email, street_address, city, state_province, postal_code, country, role, tier_id, is_active, req.params.id]
        );
        res.json({ id: req.params.id, ...req.body });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.delete('/api/users/:id', async (req, res) => {
    try {
        await query('DELETE FROM users WHERE user_id = ?', [req.params.id]);
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// User Phones
app.get('/api/user-phones', async (req, res) => {
    try {
        const rows = await query(`
            SELECT up.*, u.first_name, u.last_name 
            FROM user_phones up 
            JOIN users u ON up.user_id = u.user_id 
            ORDER BY up.phone_id
        `);
        res.json(rows);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.post('/api/user-phones', async (req, res) => {
    try {
        const { user_id, phone_number, phone_type, is_primary } = req.body;
        const result = await query(
            'INSERT INTO user_phones (user_id, phone_number, phone_type, is_primary) VALUES (?, ?, ?, ?)',
            [user_id, phone_number, phone_type, is_primary]
        );
        res.json({ id: result.insertId, ...req.body });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.put('/api/user-phones/:id', async (req, res) => {
    try {
        const { user_id, phone_number, phone_type, is_primary } = req.body;
        await query(
            'UPDATE user_phones SET user_id=?, phone_number=?, phone_type=?, is_primary=? WHERE phone_id=?',
            [user_id, phone_number, phone_type, is_primary, req.params.id]
        );
        res.json({ id: req.params.id, ...req.body });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.delete('/api/user-phones/:id', async (req, res) => {
    try {
        await query('DELETE FROM user_phones WHERE phone_id = ?', [req.params.id]);
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Categories
app.get('/api/categories', async (req, res) => {
    try {
        const rows = await query('SELECT * FROM categories ORDER BY category_id');
        res.json(rows);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.post('/api/categories', async (req, res) => {
    try {
        const { name, parent_id, description } = req.body;
        const result = await query(
            'INSERT INTO categories (name, parent_id, description) VALUES (?, ?, ?)',
            [name, parent_id, description]
        );
        res.json({ id: result.insertId, ...req.body });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.put('/api/categories/:id', async (req, res) => {
    try {
        const { name, parent_id, description } = req.body;
        await query(
            'UPDATE categories SET name=?, parent_id=?, description=? WHERE category_id=?',
            [name, parent_id, description, req.params.id]
        );
        res.json({ id: req.params.id, ...req.body });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.delete('/api/categories/:id', async (req, res) => {
    try {
        await query('DELETE FROM categories WHERE category_id = ?', [req.params.id]);
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Languages
app.get('/api/languages', async (req, res) => {
    try {
        const rows = await query('SELECT * FROM languages ORDER BY language_id');
        res.json(rows);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.post('/api/languages', async (req, res) => {
    try {
        const { language_name, iso_code } = req.body;
        const result = await query(
            'INSERT INTO languages (language_name, iso_code) VALUES (?, ?)',
            [language_name, iso_code]
        );
        res.json({ id: result.insertId, ...req.body });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.put('/api/languages/:id', async (req, res) => {
    try {
        const { language_name, iso_code } = req.body;
        await query(
            'UPDATE languages SET language_name=?, iso_code=? WHERE language_id=?',
            [language_name, iso_code, req.params.id]
        );
        res.json({ id: req.params.id, ...req.body });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.delete('/api/languages/:id', async (req, res) => {
    try {
        await query('DELETE FROM languages WHERE language_id = ?', [req.params.id]);
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Author Roles
app.get('/api/author-roles', async (req, res) => {
    try {
        const rows = await query('SELECT * FROM author_roles ORDER BY role_id');
        res.json(rows);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.post('/api/author-roles', async (req, res) => {
    try {
        const { role_name } = req.body;
        const result = await query('INSERT INTO author_roles (role_name) VALUES (?)', [role_name]);
        res.json({ id: result.insertId, ...req.body });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.put('/api/author-roles/:id', async (req, res) => {
    try {
        const { role_name } = req.body;
        await query('UPDATE author_roles SET role_name=? WHERE role_id=?', [role_name, req.params.id]);
        res.json({ id: req.params.id, ...req.body });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.delete('/api/author-roles/:id', async (req, res) => {
    try {
        await query('DELETE FROM author_roles WHERE role_id = ?', [req.params.id]);
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Copy Conditions
app.get('/api/copy-conditions', async (req, res) => {
    try {
        const rows = await query('SELECT * FROM copy_conditions ORDER BY condition_id');
        res.json(rows);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.post('/api/copy-conditions', async (req, res) => {
    try {
        const { condition_name, description } = req.body;
        const result = await query('INSERT INTO copy_conditions (condition_name, description) VALUES (?, ?)', [condition_name, description]);
        res.json({ id: result.insertId, ...req.body });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.put('/api/copy-conditions/:id', async (req, res) => {
    try {
        const { condition_name, description } = req.body;
        await query('UPDATE copy_conditions SET condition_name=?, description=? WHERE condition_id=?', [condition_name, description, req.params.id]);
        res.json({ id: req.params.id, ...req.body });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.delete('/api/copy-conditions/:id', async (req, res) => {
    try {
        await query('DELETE FROM copy_conditions WHERE condition_id = ?', [req.params.id]);
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Authors
app.get('/api/authors', async (req, res) => {
    try {
        const rows = await query('SELECT * FROM authors ORDER BY author_id');
        res.json(rows);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.post('/api/authors', async (req, res) => {
    try {
        const { first_name, last_name, bio, birth_year, nationality } = req.body;
        const result = await query(
            'INSERT INTO authors (first_name, last_name, bio, birth_year, nationality) VALUES (?, ?, ?, ?, ?)',
            [first_name, last_name, bio, birth_year, nationality]
        );
        res.json({ id: result.insertId, ...req.body });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.put('/api/authors/:id', async (req, res) => {
    try {
        const { first_name, last_name, bio, birth_year, nationality } = req.body;
        await query(
            'UPDATE authors SET first_name=?, last_name=?, bio=?, birth_year=?, nationality=? WHERE author_id=?',
            [first_name, last_name, bio, birth_year, nationality, req.params.id]
        );
        res.json({ id: req.params.id, ...req.body });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.delete('/api/authors/:id', async (req, res) => {
    try {
        await query('DELETE FROM authors WHERE author_id = ?', [req.params.id]);
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Books
app.get('/api/books', async (req, res) => {
    try {
        const rows = await query(`
            SELECT b.*, c.name as category_name 
            FROM books b 
            LEFT JOIN categories c ON b.category_id = c.category_id 
            ORDER BY b.book_id
        `);
        res.json(rows);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.post('/api/books', async (req, res) => {
    try {
        const { isbn, title, category_id, publisher, published_year, edition, description, cover_image_url } = req.body;
        const result = await query(
            `INSERT INTO books (isbn, title, category_id, publisher, published_year, edition, description, cover_image_url) 
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
            [isbn, title, category_id, publisher, published_year, edition, description, cover_image_url]
        );
        res.json({ id: result.insertId, ...req.body });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.put('/api/books/:id', async (req, res) => {
    try {
        const { isbn, title, category_id, publisher, published_year, edition, description, cover_image_url } = req.body;
        await query(
            `UPDATE books SET isbn=?, title=?, category_id=?, publisher=?, published_year=?, edition=?, description=?, cover_image_url=? WHERE book_id=?`,
            [isbn, title, category_id, publisher, published_year, edition, description, cover_image_url, req.params.id]
        );
        res.json({ id: req.params.id, ...req.body });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.delete('/api/books/:id', async (req, res) => {
    try {
        await query('DELETE FROM books WHERE book_id = ?', [req.params.id]);
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Book Languages
app.get('/api/book-languages', async (req, res) => {
    try {
        const rows = await query(`
            SELECT bl.*, b.title, l.language_name 
            FROM book_languages bl 
            JOIN books b ON bl.book_id = b.book_id 
            JOIN languages l ON bl.language_id = l.language_id 
            ORDER BY bl.book_id
        `);
        res.json(rows);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.post('/api/book-languages', async (req, res) => {
    try {
        const { book_id, language_id } = req.body;
        await query('INSERT INTO book_languages (book_id, language_id) VALUES (?, ?)', [book_id, language_id]);
        res.json(req.body);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.delete('/api/book-languages/:book_id/:language_id', async (req, res) => {
    try {
        await query('DELETE FROM book_languages WHERE book_id=? AND language_id=?', [req.params.book_id, req.params.language_id]);
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Book Authors
app.get('/api/book-authors', async (req, res) => {
    try {
        const rows = await query(`
            SELECT ba.*, b.title, a.first_name, a.last_name, ar.role_name 
            FROM book_authors ba 
            JOIN books b ON ba.book_id = b.book_id 
            JOIN authors a ON ba.author_id = a.author_id 
            JOIN author_roles ar ON ba.role_id = ar.role_id 
            ORDER BY ba.book_id
        `);
        res.json(rows);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.post('/api/book-authors', async (req, res) => {
    try {
        const { book_id, author_id, role_id } = req.body;
        await query('INSERT INTO book_authors (book_id, author_id, role_id) VALUES (?, ?, ?)', [book_id, author_id, role_id]);
        res.json(req.body);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.delete('/api/book-authors/:book_id/:author_id/:role_id', async (req, res) => {
    try {
        await query('DELETE FROM book_authors WHERE book_id=? AND author_id=? AND role_id=?', [req.params.book_id, req.params.author_id, req.params.role_id]);
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Book Copies
app.get('/api/book-copies', async (req, res) => {
    try {
        const rows = await query(`
            SELECT bc.*, b.title, cc.condition_name 
            FROM book_copies bc 
            JOIN books b ON bc.book_id = b.book_id 
            JOIN copy_conditions cc ON bc.condition_id = cc.condition_id 
            ORDER BY bc.copy_id
        `);
        res.json(rows);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.post('/api/book-copies', async (req, res) => {
    try {
        const { book_id, barcode, condition_id, is_available, location_shelf, acquired_date } = req.body;
        const result = await query(
            `INSERT INTO book_copies (book_id, barcode, condition_id, is_available, location_shelf, acquired_date) 
             VALUES (?, ?, ?, ?, ?, ?)`,
            [book_id, barcode, condition_id, is_available, location_shelf, acquired_date]
        );
        res.json({ id: result.insertId, ...req.body });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.put('/api/book-copies/:id', async (req, res) => {
    try {
        const { book_id, barcode, condition_id, is_available, location_shelf, acquired_date } = req.body;
        await query(
            `UPDATE book_copies SET book_id=?, barcode=?, condition_id=?, is_available=?, location_shelf=?, acquired_date=? WHERE copy_id=?`,
            [book_id, barcode, condition_id, is_available, location_shelf, acquired_date, req.params.id]
        );
        res.json({ id: req.params.id, ...req.body });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.delete('/api/book-copies/:id', async (req, res) => {
    try {
        await query('DELETE FROM book_copies WHERE copy_id = ?', [req.params.id]);
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Loans
app.get('/api/loans', async (req, res) => {
    try {
        const rows = await query(`
            SELECT l.*, u.first_name, u.last_name, b.title, ub.first_name as issued_first, ub.last_name as issued_last
            FROM loans l 
            JOIN users u ON l.user_id = u.user_id 
            JOIN book_copies bc ON l.copy_id = bc.copy_id 
            JOIN books b ON bc.book_id = b.book_id 
            LEFT JOIN users ub ON l.issued_by = ub.user_id 
            ORDER BY l.loan_id DESC
        `);
        res.json(rows);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.post('/api/loans', async (req, res) => {
    try {
        const { user_id, copy_id, issued_by, loan_date, due_date, notes } = req.body;
        const result = await query(
            `INSERT INTO loans (user_id, copy_id, issued_by, loan_date, due_date, notes, status) 
             VALUES (?, ?, ?, ?, ?, ?, 'active')`,
            [user_id, copy_id, issued_by, loan_date, due_date, notes]
        );
        // Update copy availability
        await query('UPDATE book_copies SET is_available = 0 WHERE copy_id = ?', [copy_id]);
        res.json({ id: result.insertId, ...req.body });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.put('/api/loans/:id', async (req, res) => {
    try {
        const { user_id, copy_id, issued_by, loan_date, due_date, return_date, status, notes } = req.body;
        await query(
            `UPDATE loans SET user_id=?, copy_id=?, issued_by=?, loan_date=?, due_date=?, return_date=?, status=?, notes=? WHERE loan_id=?`,
            [user_id, copy_id, issued_by, loan_date, due_date, return_date, status, notes, req.params.id]
        );
        // If returned, update copy availability
        if (status === 'returned') {
            await query('UPDATE book_copies SET is_available = 1 WHERE copy_id = ?', [copy_id]);
        }
        res.json({ id: req.params.id, ...req.body });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.delete('/api/loans/:id', async (req, res) => {
    try {
        const loan = await query('SELECT copy_id FROM loans WHERE loan_id = ?', [req.params.id]);
        if (loan.length > 0 && loan[0].status !== 'returned') {
            await query('UPDATE book_copies SET is_available = 1 WHERE copy_id = ?', [loan[0].copy_id]);
        }
        await query('DELETE FROM loans WHERE loan_id = ?', [req.params.id]);
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Reservations
app.get('/api/reservations', async (req, res) => {
    try {
        const rows = await query(`
            SELECT r.*, u.first_name, u.last_name, b.title 
            FROM reservations r 
            JOIN users u ON r.user_id = u.user_id 
            JOIN books b ON r.book_id = b.book_id 
            ORDER BY r.reservation_id DESC
        `);
        res.json(rows);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.post('/api/reservations', async (req, res) => {
    try {
        const { user_id, book_id, status } = req.body;
        const result = await query(
            `INSERT INTO reservations (user_id, book_id, status) VALUES (?, ?, ?)`,
            [user_id, book_id, status || 'pending']
        );
        res.json({ id: result.insertId, ...req.body });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.put('/api/reservations/:id', async (req, res) => {
    try {
        const { user_id, book_id, status, fulfilled_loan } = req.body;
        await query(
            `UPDATE reservations SET user_id=?, book_id=?, status=?, fulfilled_loan=? WHERE reservation_id=?`,
            [user_id, book_id, status, fulfilled_loan, req.params.id]
        );
        res.json({ id: req.params.id, ...req.body });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.delete('/api/reservations/:id', async (req, res) => {
    try {
        await query('DELETE FROM reservations WHERE reservation_id = ?', [req.params.id]);
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Fines
app.get('/api/fines', async (req, res) => {
    try {
        const rows = await query(`
            SELECT f.*, u.first_name, u.last_name, l.loan_id 
            FROM fines f 
            JOIN users u ON f.user_id = u.user_id 
            JOIN loans l ON f.loan_id = l.loan_id 
            ORDER BY f.fine_id DESC
        `);
        res.json(rows);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.post('/api/fines', async (req, res) => {
    try {
        const { loan_id, user_id, overdue_days, amount, status, notes } = req.body;
        const result = await query(
            `INSERT INTO fines (loan_id, user_id, overdue_days, amount, status, notes) 
             VALUES (?, ?, ?, ?, ?, ?)`,
            [loan_id, user_id, overdue_days, amount, status || 'unpaid', notes]
        );
        res.json({ id: result.insertId, ...req.body });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.put('/api/fines/:id', async (req, res) => {
    try {
        const { loan_id, user_id, overdue_days, amount, status, collected_by, paid_at, notes } = req.body;
        await query(
            `UPDATE fines SET loan_id=?, user_id=?, overdue_days=?, amount=?, status=?, collected_by=?, paid_at=?, notes=? WHERE fine_id=?`,
            [loan_id, user_id, overdue_days, amount, status, collected_by, paid_at, notes, req.params.id]
        );
        res.json({ id: req.params.id, ...req.body });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.delete('/api/fines/:id', async (req, res) => {
    try {
        await query('DELETE FROM fines WHERE fine_id = ?', [req.params.id]);
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Start server
app.listen(PORT, () => {
    console.log(`Server running at http://localhost:${PORT}`);
    console.log('Open index.html in your browser to use the application');
});
