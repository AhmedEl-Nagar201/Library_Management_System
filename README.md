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

### Role-Based Access Control (RBAC)

The system implements comprehensive authorization with different views and permissions for each role:

#### Admin
- **Full system access** to all features and data
- Manage all users (create, edit, delete)
- View and manage all books, loans, reservations, and fines
- Access system settings and configuration
- View analytics and reports across all users

#### Librarian
- **Operational access** for daily library management
- Manage books (add, edit, delete)
- Process loans and returns
- Handle reservations
- Manage fines and payments
- **Cannot** access user management or system settings
- **Cannot** view other librarians' or admins' personal data

#### Member (Student/User)
- **Limited access** to personal data only
- View their own loans and loan history
- View their own reservations
- View and pay their own fines
- Browse and search the book catalog
- **Cannot** see other users' data, loans, or personal information
- **Cannot** access administrative functions
- **Cannot** modify system data

### Security Implementation
- **Frontend**: Dynamic UI rendering based on user role - tabs and features are hidden/shown accordingly
- **Backend**: API endpoints filter data by user ID for members, ensuring they can only retrieve their own records
- **Authentication**: Role verification on every protected route
- **Data Isolation**: Members cannot access data belonging to other users through direct API calls

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

- **Frontend**: Plain HTML, Vanilla JavaScript, Tailwind CSS (via CDN)
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
