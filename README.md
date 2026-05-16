# Library Management System

A fully functional web application for managing a library, built with plain HTML, JavaScript, and Tailwind CSS frontend with a Node.js/Express backend connecting to MySQL.

## Prerequisites

1. **MySQL Server** running locally with:
   - Host: `127.0.0.1`
   - User: `root`
   - Password: `admin`

2. **Node.js** (v14 or higher)

## Setup Instructions

### 1. Create the Database

Run the SQL file to create the database and tables:

```bash
mysql -u root -padmin < "library_management_1NF - Copy.sql"
```

Or open the SQL file in MySQL Workbench/phpMyAdmin and execute it.

### 2. Install Dependencies

```bash
npm install
```

### 3. Start the Server

```bash
npm start
```

The server will start at `http://localhost:3000`

### 4. Open the Application

Open `index.html` in your browser, or navigate to `http://localhost:3000` after starting the server.

## Creating Test Users

Before logging in, you need to create users in the database. Run these SQL commands:

```sql
USE library_management_system;

-- Admin user
INSERT INTO users (first_name, last_name, email, password_hash, role, tier_id, country) 
VALUES ('Admin', 'User', 'admin@library.com', 'admin123', 'admin', 1, 'Egypt');

-- Librarian user
INSERT INTO users (first_name, last_name, email, password_hash, role, tier_id, country) 
VALUES ('Librarian', 'Staff', 'librarian@library.com', 'lib123', 'librarian', 1, 'Egypt');

-- Member user
INSERT INTO users (first_name, last_name, email, password_hash, role, tier_id, country) 
VALUES ('John', 'Doe', 'member@library.com', 'member123', 'member', 1, 'Egypt');
```

## Features

### Role-Based Access
- **Member**: View loans, reservations, browse books
- **Librarian**: Issue loans, process returns, manage books
- **Admin**: Full access including user management and system settings

### All Schema Tables Covered
1. Membership Tiers
2. Users (with split name/address fields per 1NF)
3. User Phones (separate table for multi-valued phone attribute)
4. Categories
5. Languages
6. Author Roles
7. Copy Conditions
8. Authors (with split name fields per 1NF)
9. Books
10. Book Languages (junction table for many-to-many)
11. Book Authors (junction table with roles)
12. Book Copies
13. Loans
14. Reservations
15. Fines

### Form Controls
- Text inputs for names, titles, descriptions
- Number inputs with min/max constraints
- Date pickers for dates
- Dropdown selects for ENUMs and foreign keys
- Checkboxes for boolean fields
- Textareas for long text

## Technology Stack

- **Frontend**: Plain HTML, Vanilla JavaScript, Tailwind CSS (via CDN), Tom Select
- **Backend**: Node.js with Express
- **Database**: MySQL with mysql2 driver
- **API**: RESTful JSON API

## File Structure

```
/workspace/
├── index.html              # Main frontend application
├── server.js               # Express backend server
├── package.json            # Node.js dependencies
├── local.txt               # Database credentials reference
├── library_management_1NF - Copy.sql  # Database schema
└── README.md               # This file
```

## Code Snippets & Reusable Patterns

### Backend Helper Functions

#### Database Query Helper
Reusable async query function used throughout `server.js`:

```javascript
async function query(sql, params = []) {
    if (!pool) throw new Error('Database not connected');
    const [rows] = await pool.execute(sql, params);
    return rows;
}
```

#### Generic CRUD Endpoints Pattern
All tables follow this consistent RESTful pattern:

```javascript
// GET all records
app.get('/api/:table', async (req, res) => {
    try {
        const rows = await query(`SELECT * FROM :table ORDER BY :id_column`);
        res.json(rows);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// POST create new record
app.post('/api/:table', async (req, res) => {
    try {
        const { field1, field2, field3 } = req.body;
        const result = await query(
            `INSERT INTO :table (field1, field2, field3) VALUES (?, ?, ?)`,
            [field1, field2, field3]
        );
        res.json({ id: result.insertId, ...req.body });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// PUT update existing record
app.put('/api/:table/:id', async (req, res) => {
    try {
        const { field1, field2, field3 } = req.body;
        await query(
            `UPDATE :table SET field1=?, field2=?, field3=? WHERE :id_column=?`,
            [field1, field2, field3, req.params.id]
        );
        res.json({ id: req.params.id, ...req.body });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// DELETE record
app.delete('/api/:table/:id', async (req, res) => {
    try {
        await query('DELETE FROM :table WHERE :id_column = ?', [req.params.id]);
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});
```

#### Join Query Pattern
For related data with foreign keys:

```javascript
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
```

#### Cascade Update Pattern
When updating loan status, automatically update book copy availability:

```javascript
app.put('/api/loans/:id', async (req, res) => {
    try {
        const { user_id, copy_id, status } = req.body;
        await query(
            `UPDATE loans SET user_id=?, copy_id=?, status=? WHERE loan_id=?`,
            [user_id, copy_id, status, req.params.id]
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
```

### Frontend Reusable Functions

#### API Base Configuration
```javascript
const API_BASE = 'http://localhost:3000/api';
let currentUser = null;
let currentTab = 'dashboard';
let lookupData = {};
```

#### Login Handler Pattern
```javascript
document.getElementById('login-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const email = document.getElementById('login-email').value;
    const password = document.getElementById('login-password').value;
    
    try {
        const response = await fetch(`${API_BASE}/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email, password })
        });
        
        if (response.ok) {
            currentUser = await response.json();
            // Hide login, show main app
            document.getElementById('login-screen').classList.add('hidden');
            document.getElementById('main-app').classList.remove('hidden');
            loadLookupData();
            renderQuickActions();
            renderContent();
        } else {
            const error = await response.json();
            document.getElementById('login-error').textContent = error.error;
        }
    } catch (err) {
        document.getElementById('login-error').textContent = 'Cannot connect to server';
    }
});
```

#### Load Lookup Data (Dropdown Population)
```javascript
async function loadLookupData() {
    try {
        const [tiers, categories, languages, roles, conditions, users, books, authors, bookCopies] = await Promise.all([
            fetch(`${API_BASE}/membership-tiers`).then(r => r.json()),
            fetch(`${API_BASE}/categories`).then(r => r.json()),
            fetch(`${API_BASE}/languages`).then(r => r.json()),
            fetch(`${API_BASE}/author-roles`).then(r => r.json()),
            fetch(`${API_BASE}/copy-conditions`).then(r => r.json()),
            fetch(`${API_BASE}/users`).then(r => r.json()),
            fetch(`${API_BASE}/books`).then(r => r.json()),
            fetch(`${API_BASE}/authors`).then(r => r.json()),
            fetch(`${API_BASE}/book-copies`).then(r => r.json())
        ]);
        lookupData = { tiers, categories, languages, roles, conditions, users, books, authors, 'book-copies': bookCopies };
    } catch (err) {
        console.error('Failed to load lookup data:', err);
    }
}
```

#### Role-Based Quick Actions
```javascript
function renderQuickActions() {
    const container = document.getElementById('quick-actions');
    if (!currentUser) return;
    
    let actions = [];
    if (currentUser.role === 'member') {
        actions = [
            { label: 'My Loans', tab: 'loans', icon: '📚' },
            { label: 'My Reservations', tab: 'reservations', icon: '📅' },
            { label: 'Browse Books', tab: 'books', icon: '📖' }
        ];
    } else if (currentUser.role === 'librarian') {
        actions = [
            { label: 'Issue Loan', action: 'newLoan', icon: '➕' },
            { label: 'Process Return', action: 'processReturn', icon: '↩️' },
            { label: 'Manage Books', tab: 'books', icon: '📚' }
        ];
    } else if (currentUser.role === 'admin') {
        actions = [
            { label: 'Manage Users', tab: 'users', icon: '👥' },
            { label: 'System Settings', tab: 'membership-tiers', icon: '⚙️' },
            { label: 'View All Loans', tab: 'loans', icon: '📊' }
        ];
    }
    
    container.innerHTML = actions.map(a => `
        <button onclick="${a.action ? `handleQuickAction('${a.action}')` : `switchTab('${a.tab}')`}" 
            class="bg-white p-4 rounded-lg shadow hover:shadow-md transition flex items-center space-x-3">
            <span class="text-2xl">${a.icon}</span>
            <span class="font-medium">${a.label}</span>
        </button>
    `).join('');
}
```

#### Dynamic Table Rendering
```javascript
function renderTable(container, data) {
    if (!data || data.length === 0) {
        container.innerHTML = '<div class="text-center py-8 text-gray-500">No records found</div>';
        return;
    }
    
    const columns = Object.keys(data[0]).filter(k => k !== 'password_hash');
    const html = `
        <div class="flex justify-between items-center mb-4">
            <h2 class="text-xl font-bold capitalize">${currentTab.replace(/-/g, ' ')}</h2>
            <button onclick="showForm()" class="bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded">+ Add New</button>
        </div>
        <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50">
                    <tr>
                        ${columns.map(col => `<th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">${col}</th>`).join('')}
                        <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Actions</th>
                    </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                    ${data.map(row => `
                        <tr class="hover:bg-gray-50">
                            ${columns.map(col => `<td class="px-4 py-2 text-sm text-gray-900">${row[col]}</td>`).join('')}
                            <td class="px-4 py-2 text-sm">
                                <button onclick="showForm(${row[Object.keys(row)[0]]})" class="text-blue-600 hover:text-blue-800 mr-2">Edit</button>
                                <button onclick="deleteRecord(${row[Object.keys(row)[0]]})" class="text-red-600 hover:text-red-800">Delete</button>
                            </td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        </div>
    `;
    container.innerHTML = html;
}
```

#### Tab Switching Pattern
```javascript
function switchTab(tab) {
    document.querySelector(`[data-tab="${tab}"]`)?.click();
}

document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        document.querySelectorAll('.tab-btn').forEach(b => {
            b.classList.remove('active', 'border-blue-500', 'text-blue-600');
            b.classList.add('border-transparent', 'text-gray-500');
        });
        btn.classList.remove('border-transparent', 'text-gray-500');
        btn.classList.add('active', 'border-blue-500', 'text-blue-600');
        currentTab = btn.dataset.tab;
        renderContent();
    });
});
```

#### Modal Form Handling
```javascript
function showModal(content) {
    document.getElementById('modal-content').innerHTML = content;
    document.getElementById('modal').classList.remove('hidden');
}

function hideModal() {
    document.getElementById('modal').classList.add('hidden');
    editingId = null;
}

async function showForm(id = null) {
    editingId = id;
    let record = null;
    if (id) {
        const response = await fetch(`${API_BASE}/${currentTab}/${id}`);
        record = await response.json();
    }
    
    const formHtml = generateFormHtml(currentTab, record);
    showModal(formHtml);
}

async function saveForm(formData) {
    const url = editingId 
        ? `${API_BASE}/${currentTab}/${editingId}`
        : `${API_BASE}/${currentTab}`;
    const method = editingId ? 'PUT' : 'POST';
    
    const response = await fetch(url, {
        method: method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData)
    });
    
    if (response.ok) {
        hideModal();
        renderContent();
    } else {
        const error = await response.json();
        alert('Error saving: ' + error.error);
    }
}
```

## API Endpoints Reference

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/login` | POST | User authentication |
| `/api/users/:id` | GET | Get user by ID |
| `/api/membership-tiers` | GET, POST | List/Create membership tiers |
| `/api/membership-tiers/:id` | PUT, DELETE | Update/Delete membership tier |
| `/api/users` | GET, POST | List/Create users |
| `/api/users/:id` | PUT, DELETE | Update/Delete user |
| `/api/user-phones` | GET, POST | List/Create user phones |
| `/api/categories` | GET, POST | List/Create categories |
| `/api/languages` | GET, POST | List/Create languages |
| `/api/author-roles` | GET, POST | List/Create author roles |
| `/api/copy-conditions` | GET, POST | List/Create copy conditions |
| `/api/authors` | GET, POST | List/Create authors |
| `/api/books` | GET, POST | List/Create books |
| `/api/book-languages` | GET, POST, DELETE | Manage book-language relationships |
| `/api/book-authors` | GET, POST, DELETE | Manage book-author relationships |
| `/api/book-copies` | GET, POST | List/Create book copies |
| `/api/loans` | GET, POST | List/Create loans |
| `/api/reservations` | GET, POST | List/Create reservations |
| `/api/fines` | GET, POST | List/Create fines |

## Database Schema Highlights

### 1NF Normalization Applied
The database schema implements First Normal Form (1NF) by:

1. **Splitting composite attributes**:
   - `users.full_name` → `first_name` + `last_name`
   - `users.address` → `street_address`, `city`, `state_province`, `postal_code`, `country`
   - `authors.full_name` → `first_name` + `last_name`

2. **Creating separate tables for multi-valued attributes**:
   - `user_phones` table for multiple phone numbers per user

3. **Creating lookup tables for controlled vocabularies**:
   - `languages` table (instead of free-text language field)
   - `author_roles` table (instead of free-text role descriptions)
   - `copy_conditions` table (instead of free-text condition descriptions)

4. **Junction tables for many-to-many relationships**:
   - `book_languages` links books to multiple languages
   - `book_authors` links books to multiple authors with roles

## Contributing

Feel free to submit issues and enhancement requests!

## License

ISC
