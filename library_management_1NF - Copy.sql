-- ============================================================
--  LIBRARY MANAGEMENT SYSTEM — 1NF NORMALIZED (MySQL Version)
--  Changes from original schema are marked with [1NF FIX]
-- ============================================================
--
--  1NF VIOLATIONS FIXED:
--  ① users.full_name        → split into first_name + last_name         (composite/non-atomic)
--  ② users.address          → split into street, city, state, postal_code, country  (composite/non-atomic)
--  ③ users.phone            → moved to separate user_phones table        (multi-valued / repeating group)
--  ④ authors.full_name      → split into first_name + last_name          (composite/non-atomic)
--  ⑤ books.language         → moved to book_languages junction table     (potentially multi-valued)
--  ⑥ book_authors.role      → references new author_roles lookup table   (free-text allowed multi-value strings)
--  ⑦ book_copies.condition  → references new copy_conditions lookup table (repeating group of allowed values)
-- ============================================================

-- ============================================================
--  CREATE AND SELECT DATABASE
-- ============================================================
CREATE DATABASE IF NOT EXISTS library_management_system;
USE library_management_system;

-- ============================================================
--  LIBRARY MANAGEMENT SYSTEM — 1NF NORMALIZED (MySQL Version)
-- ... rest of the script continues below


-- ============================================================
--  CLEANUP
-- ============================================================
DROP TABLE IF EXISTS fines;
DROP TABLE IF EXISTS reservations;
DROP TABLE IF EXISTS loans;
DROP TABLE IF EXISTS book_copies;
DROP TABLE IF EXISTS book_languages;
DROP TABLE IF EXISTS book_authors;
DROP TABLE IF EXISTS books;
DROP TABLE IF EXISTS copy_conditions;
DROP TABLE IF EXISTS author_roles;
DROP TABLE IF EXISTS authors;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS user_phones;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS membership_tiers;
DROP TABLE IF EXISTS languages;

DROP PROCEDURE IF EXISTS fn_check_borrow_limit;
DROP PROCEDURE IF EXISTS fn_sync_copy_availability;
DROP PROCEDURE IF EXISTS fn_auto_generate_fine;
DROP PROCEDURE IF EXISTS fn_expire_reservations;
DROP PROCEDURE IF EXISTS fn_mark_overdue_loans;

DROP FUNCTION IF EXISTS fn_calculate_fine;


-- ============================================================
--  1. MEMBERSHIP TIERS  (unchanged — already 1NF)
-- ============================================================
CREATE TABLE membership_tiers (
    tier_id            INT AUTO_INCREMENT PRIMARY KEY,
    tier_name          VARCHAR(50)     NOT NULL UNIQUE,
    max_books          INT             NOT NULL DEFAULT 3,
    loan_duration_days INT             NOT NULL DEFAULT 14,
    fine_per_day       DECIMAL(6,2)    NOT NULL DEFAULT 1.00,
    CONSTRAINT chk_max_books CHECK (max_books BETWEEN 1 AND 20),
    CONSTRAINT chk_loan_duration CHECK (loan_duration_days BETWEEN 1 AND 90),
    CONSTRAINT chk_fine_per_day CHECK (fine_per_day >= 0)
);

INSERT INTO membership_tiers (tier_name, max_books, loan_duration_days, fine_per_day) VALUES
    ('Student',   3,  14, 0.50),
    ('Standard',  5,  21, 1.00),
    ('Premium',   10, 30, 0.50),
    ('Staff',     15, 60, 0.00);


-- ============================================================
--  2. USERS  [1NF FIX ① ②]
--     • full_name  split into first_name + last_name
--     • address    split into atomic address columns
--     • phone      removed (moved to user_phones table below)
-- ============================================================
CREATE TABLE users (
    user_id        INT AUTO_INCREMENT PRIMARY KEY,
    national_id    VARCHAR(20)     UNIQUE,

    -- [1NF FIX ①] Composite full_name → two atomic columns
    first_name     VARCHAR(75)     NOT NULL,
    last_name      VARCHAR(75)     NOT NULL,

    email          VARCHAR(254)    NOT NULL UNIQUE,

    -- [1NF FIX ②] Free-text address → four atomic columns
    street_address VARCHAR(200),
    city           VARCHAR(100),
    state_province VARCHAR(100),
    postal_code    VARCHAR(20),
    country        VARCHAR(100)    NOT NULL DEFAULT 'Egypt',

    -- NOTE: phone column removed — see user_phones table [1NF FIX ③]

    role           ENUM('member', 'librarian', 'admin') NOT NULL DEFAULT 'member',
    tier_id        INT             NOT NULL DEFAULT 1,
    is_active      TINYINT(1)      NOT NULL DEFAULT 1,
    registered_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    password_hash  VARCHAR(255)    NOT NULL,
    FOREIGN KEY (tier_id) REFERENCES membership_tiers(tier_id) ON UPDATE CASCADE
);

CREATE INDEX idx_users_email      ON users(email);
CREATE INDEX idx_users_role       ON users(role);
CREATE INDEX idx_users_last_name  ON users(last_name);


-- ============================================================
--  3. USER PHONES  [1NF FIX ③]
--     Replacing users.phone (single free-text column that could
--     hold comma-separated numbers) with a proper child table.
--     Each row is one atomic phone number for one user.
-- ============================================================
CREATE TABLE user_phones (
    phone_id      INT AUTO_INCREMENT PRIMARY KEY,
    user_id       INT             NOT NULL,
    phone_number  VARCHAR(30)     NOT NULL,
    phone_type    ENUM('mobile', 'home', 'work', 'fax') NOT NULL DEFAULT 'mobile',
    is_primary    TINYINT(1)      NOT NULL DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE INDEX idx_phones_user ON user_phones(user_id);


-- ============================================================
--  4. CATEGORIES  (unchanged — already 1NF)
-- ============================================================
CREATE TABLE categories (
    category_id   INT AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(100)    NOT NULL UNIQUE,
    parent_id     INT,
    description   TEXT,
    FOREIGN KEY (parent_id) REFERENCES categories(category_id) ON DELETE SET NULL
);

INSERT INTO categories (name, description) VALUES
    ('Fiction',     'Narrative literature'),
    ('Non-Fiction',  'Factual and informational works'),
    ('Science',      'Natural and applied sciences'),
    ('History',      'Historical accounts and analysis'),
    ('Technology',   'Computing, engineering, and technology'),
    ('Children',     'Books for young readers'),
    ('Reference',    'Encyclopedias, dictionaries, almanacs');


-- ============================================================
--  5. LANGUAGES  [1NF FIX ⑤ — new lookup table]
--     Replaces the free-text books.language column.
-- ============================================================
CREATE TABLE languages (
    language_id   INT AUTO_INCREMENT PRIMARY KEY,
    language_name VARCHAR(80)     NOT NULL UNIQUE,   -- e.g. 'English', 'Arabic'
    iso_code      CHAR(3)         NOT NULL UNIQUE    -- ISO 639-2 code, e.g. 'eng', 'ara'
);

INSERT INTO languages (language_name, iso_code) VALUES
    ('English', 'eng'),
    ('Arabic',  'ara'),
    ('French',  'fra'),
    ('German',  'deu'),
    ('Spanish', 'spa');


-- ============================================================
--  6. AUTHOR ROLES  [1NF FIX ⑥ — new lookup table]
--     Replaces free-text book_authors.role which allowed
--     strings like "author, editor" in a single cell.
-- ============================================================
CREATE TABLE author_roles (
    role_id    INT AUTO_INCREMENT PRIMARY KEY,
    role_name  VARCHAR(50)     NOT NULL UNIQUE   -- 'Author', 'Editor', 'Translator', etc.
);

INSERT INTO author_roles (role_name) VALUES
    ('Author'),
    ('Co-Author'),
    ('Editor'),
    ('Translator'),
    ('Illustrator'),
    ('Foreword');


-- ============================================================
--  7. COPY CONDITIONS  [1NF FIX ⑦ — new lookup table]
--     Replaces the inline CHECK list in book_copies.condition,
--     making condition values a proper referenced entity.
-- ============================================================
CREATE TABLE copy_conditions (
    condition_id    INT AUTO_INCREMENT PRIMARY KEY,
    condition_name  VARCHAR(30)     NOT NULL UNIQUE,
    description     TEXT
);

INSERT INTO copy_conditions (condition_name, description) VALUES
    ('New',     'Unused, no marks or wear'),
    ('Good',    'Minor wear, fully readable'),
    ('Fair',    'Noticeable wear, still usable'),
    ('Poor',    'Heavy wear, readable with difficulty'),
    ('Damaged', 'Physical damage, may affect use'),
    ('Lost',    'Copy reported missing');


-- ============================================================
--  8. AUTHORS  [1NF FIX ④]
--     full_name split into first_name + last_name
-- ============================================================
CREATE TABLE authors (
    author_id   INT AUTO_INCREMENT PRIMARY KEY,

    -- [1NF FIX ④] Composite full_name → two atomic columns
    first_name  VARCHAR(75)     NOT NULL,
    last_name   VARCHAR(75)     NOT NULL,

    bio         TEXT,
    birth_year  INT,
    nationality VARCHAR(100)
);


-- ============================================================
--  9. BOOKS  [1NF FIX ⑤]
--     language column removed (now in book_languages junction)
-- ============================================================
CREATE TABLE books (
    book_id          INT AUTO_INCREMENT PRIMARY KEY,
    isbn             VARCHAR(20)     NOT NULL UNIQUE,
    title            VARCHAR(300)    NOT NULL,
    category_id      INT,
    publisher        VARCHAR(200),
    published_year   INT,
    edition          VARCHAR(50),
    -- [1NF FIX ⑤] language column removed — see book_languages table
    description      TEXT,
    cover_image_url  VARCHAR(500),
    added_at         TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE SET NULL
);

CREATE INDEX idx_books_title    ON books(title);
CREATE INDEX idx_books_isbn     ON books(isbn);
CREATE INDEX idx_books_category ON books(category_id);


-- ============================================================
--  10. BOOK–LANGUAGE  [1NF FIX ⑤ — new junction table]
--      One row per language a book is published in.
--      A bilingual book gets two rows; a monolingual book gets one.
-- ============================================================
CREATE TABLE book_languages (
    book_id      INT NOT NULL,
    language_id  INT NOT NULL,
    PRIMARY KEY (book_id, language_id),
    FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE,
    FOREIGN KEY (language_id) REFERENCES languages(language_id) ON DELETE RESTRICT
);


-- ============================================================
--  11. BOOK–AUTHOR  [1NF FIX ⑥]
--      role column now references author_roles instead of free text.
--      Each row captures exactly ONE author in ONE role for ONE book.
-- ============================================================
CREATE TABLE book_authors (
    book_id    INT NOT NULL,
    author_id  INT NOT NULL,
    role_id    INT NOT NULL,
    PRIMARY KEY (book_id, author_id, role_id),
    FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE,
    FOREIGN KEY (author_id) REFERENCES authors(author_id) ON DELETE CASCADE,
    FOREIGN KEY (role_id) REFERENCES author_roles(role_id)
);


-- ============================================================
--  12. BOOK COPIES  [1NF FIX ⑦]
--      condition now references copy_conditions table
-- ============================================================
CREATE TABLE book_copies (
    copy_id        INT AUTO_INCREMENT PRIMARY KEY,
    book_id        INT      NOT NULL,
    barcode        VARCHAR(50) UNIQUE,
    -- [1NF FIX ⑦] condition VARCHAR + CHECK → FK to copy_conditions
    condition_id   INT      NOT NULL DEFAULT 2,    -- 2 = 'Good'
    is_available   TINYINT(1) NOT NULL DEFAULT 1,
    location_shelf VARCHAR(50),
    acquired_date  DATE,
    FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE,
    FOREIGN KEY (condition_id) REFERENCES copy_conditions(condition_id)
);

CREATE INDEX idx_copies_book      ON book_copies(book_id);
CREATE INDEX idx_copies_available ON book_copies(is_available);


-- ============================================================
--  13. LOANS  (unchanged — already 1NF)
-- ============================================================
CREATE TABLE loans (
    loan_id      INT AUTO_INCREMENT PRIMARY KEY,
    user_id      INT          NOT NULL,
    copy_id      INT          NOT NULL,
    issued_by    INT,
    loan_date    DATE         NOT NULL DEFAULT (CURRENT_DATE),
    due_date     DATE         NOT NULL,
    return_date  DATE,
    status       ENUM('active', 'returned', 'overdue') NOT NULL DEFAULT 'active',
    notes        TEXT,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE RESTRICT,
    FOREIGN KEY (copy_id) REFERENCES book_copies(copy_id) ON DELETE RESTRICT,
    FOREIGN KEY (issued_by) REFERENCES users(user_id),
    CONSTRAINT chk_due_after_loan    CHECK (due_date > loan_date),
    CONSTRAINT chk_return_after_loan CHECK (return_date IS NULL OR return_date >= loan_date)
);

CREATE INDEX idx_loans_user     ON loans(user_id);
CREATE INDEX idx_loans_copy     ON loans(copy_id);
CREATE INDEX idx_loans_status   ON loans(status);
CREATE INDEX idx_loans_due_date ON loans(due_date);


-- ============================================================
--  14. RESERVATIONS  (unchanged — already 1NF)
-- ============================================================
CREATE TABLE reservations (
    reservation_id  INT AUTO_INCREMENT PRIMARY KEY,
    user_id         INT                 NOT NULL,
    book_id         INT                 NOT NULL,
    reserved_at     TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at      TIMESTAMP           NOT NULL DEFAULT (CURRENT_TIMESTAMP + INTERVAL 3 DAY),
    status          ENUM('pending', 'fulfilled', 'cancelled', 'expired') NOT NULL DEFAULT 'pending',
    fulfilled_loan  INT,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE,
    FOREIGN KEY (fulfilled_loan) REFERENCES loans(loan_id)
);

CREATE INDEX idx_reservations_user   ON reservations(user_id);
CREATE INDEX idx_reservations_book   ON reservations(book_id);
CREATE INDEX idx_reservations_status ON reservations(status);


-- ============================================================
--  15. FINES  (unchanged — already 1NF)
-- ============================================================
CREATE TABLE fines (
    fine_id       INT AUTO_INCREMENT PRIMARY KEY,
    loan_id       INT          NOT NULL UNIQUE,
    user_id       INT          NOT NULL,
    overdue_days  INT          NOT NULL,
    amount        DECIMAL(10,2) NOT NULL,
    status        ENUM('unpaid', 'paid', 'waived') NOT NULL DEFAULT 'unpaid',
    issued_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    paid_at       TIMESTAMP    NULL,
    collected_by  INT,
    notes         TEXT,
    FOREIGN KEY (loan_id) REFERENCES loans(loan_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (collected_by) REFERENCES users(user_id),
    CONSTRAINT chk_overdue_days CHECK (overdue_days > 0),
    CONSTRAINT chk_amount CHECK (amount >= 0)
);

CREATE INDEX idx_fines_user   ON fines(user_id);
CREATE INDEX idx_fines_status ON fines(status);


-- ============================================================
--  FUNCTIONS & STORED PROCEDURES
-- ============================================================

DELIMITER $$

-- Function to calculate fine amount
CREATE FUNCTION fn_calculate_fine(
    p_due_date     DATE,
    p_return_date  DATE,
    p_rate_per_day DECIMAL(10,2)
) RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE days_diff INT;
    SET days_diff = DATEDIFF(p_return_date, p_due_date);
    IF days_diff <= 0 THEN
        RETURN 0.00;
    END IF;
    RETURN days_diff * p_rate_per_day;
END$$

-- Procedure to expire reservations
CREATE PROCEDURE fn_expire_reservations()
BEGIN
    UPDATE reservations 
    SET status = 'expired'
    WHERE status = 'pending' AND expires_at < NOW();
END$$

-- Procedure to mark overdue loans
CREATE PROCEDURE fn_mark_overdue_loans()
BEGIN
    UPDATE loans 
    SET status = 'overdue'
    WHERE status = 'active' AND due_date < CURRENT_DATE;
END$$

DELIMITER ;


-- ============================================================
--  TRIGGERS
-- ============================================================

DELIMITER $$

-- Trigger: Check borrow limit before inserting a loan
CREATE TRIGGER trg_check_borrow_limit
    BEFORE INSERT ON loans
    FOR EACH ROW
BEGIN
    DECLARE v_active_loans INT;
    DECLARE v_max_books INT;
    
    SELECT COUNT(*) INTO v_active_loans
    FROM loans 
    WHERE user_id = NEW.user_id AND status = 'active';
    
    SELECT mt.max_books INTO v_max_books
    FROM users u
    JOIN membership_tiers mt ON mt.tier_id = u.tier_id
    WHERE u.user_id = NEW.user_id;
    
    IF v_active_loans >= v_max_books THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Borrow limit reached. User has reached maximum active loans.';
    END IF;
END$$

-- Trigger: Sync copy availability when loan is inserted
CREATE TRIGGER trg_sync_copy_availability_insert
    AFTER INSERT ON loans
    FOR EACH ROW
BEGIN
    IF NEW.status = 'active' THEN
        UPDATE book_copies SET is_available = 0 WHERE copy_id = NEW.copy_id;
    END IF;
END$$

-- Trigger: Sync copy availability when loan is updated (returned)
CREATE TRIGGER trg_sync_copy_availability_update
    AFTER UPDATE ON loans
    FOR EACH ROW
BEGIN
    IF NEW.return_date IS NOT NULL AND OLD.return_date IS NULL THEN
        UPDATE book_copies SET is_available = 1 WHERE copy_id = NEW.copy_id;
    END IF;
END$$

-- Trigger: Auto-generate fine when book is returned late
CREATE TRIGGER trg_auto_generate_fine
    AFTER UPDATE ON loans
    FOR EACH ROW
BEGIN
    DECLARE v_days_overdue INT;
    DECLARE v_rate DECIMAL(10,2);
    
    IF NEW.return_date IS NULL OR OLD.return_date IS NOT NULL THEN
        -- Not a return event, skip
        -- Use LEAVE-like behavior by doing nothing
        SET @skip = 1;
    ELSE
        SET v_days_overdue = DATEDIFF(NEW.return_date, NEW.due_date);
        
        IF v_days_overdue > 0 THEN
            SELECT mt.fine_per_day INTO v_rate
            FROM users u
            JOIN membership_tiers mt ON mt.tier_id = u.tier_id
            WHERE u.user_id = NEW.user_id;
            
            INSERT INTO fines (loan_id, user_id, overdue_days, amount)
            VALUES (NEW.loan_id, NEW.user_id, v_days_overdue, 
                    fn_calculate_fine(NEW.due_date, NEW.return_date, v_rate))
            ON DUPLICATE KEY UPDATE loan_id = loan_id; -- Do nothing on duplicate
        END IF;
    END IF;
END$$

DELIMITER ;


-- ============================================================
--  VIEWS  (updated to use new atomic columns)
-- ============================================================

CREATE OR REPLACE VIEW vw_active_loans AS
SELECT
    l.loan_id,
    u.user_id,
    CONCAT(u.first_name, ' ', u.last_name) AS borrower_name,   -- [1NF FIX ①]
    u.email,
    b.book_id,
    b.title,
    b.isbn,
    bc.copy_id,
    bc.barcode,
    l.loan_date,
    l.due_date,
    DATEDIFF(l.due_date, CURRENT_DATE) AS days_remaining,
    l.status
FROM   loans l
JOIN   users       u  ON u.user_id  = l.user_id
JOIN   book_copies bc ON bc.copy_id = l.copy_id
JOIN   books       b  ON b.book_id  = bc.book_id
WHERE  l.status IN ('active', 'overdue');


CREATE OR REPLACE VIEW vw_overdue_loans AS
SELECT
    l.loan_id,
    CONCAT(u.first_name, ' ', u.last_name) AS borrower_name,
    u.email,
    b.title,
    l.due_date,
    DATEDIFF(CURRENT_DATE, l.due_date) AS days_overdue,
    mt.fine_per_day,
    fn_calculate_fine(l.due_date, CURRENT_DATE, mt.fine_per_day) AS estimated_fine
FROM   loans l
JOIN   users            u  ON u.user_id  = l.user_id
JOIN   membership_tiers mt ON mt.tier_id = u.tier_id
JOIN   book_copies      bc ON bc.copy_id = l.copy_id
JOIN   books            b  ON b.book_id  = bc.book_id
WHERE  l.status = 'overdue';


CREATE OR REPLACE VIEW vw_most_borrowed_books AS
SELECT
    b.book_id,
    b.title,
    b.isbn,
    c.name AS category,
    GROUP_CONCAT(DISTINCT CONCAT(a.first_name, ' ', a.last_name) 
                 ORDER BY CONCAT(a.last_name, ' ', a.first_name) 
                 SEPARATOR ', ') AS authors,          -- [1NF FIX ④]
    COUNT(l.loan_id) AS total_loans
FROM   books b
LEFT JOIN book_copies  bc ON bc.book_id   = b.book_id
LEFT JOIN loans        l  ON l.copy_id    = bc.copy_id
LEFT JOIN categories   c  ON c.category_id = b.category_id
LEFT JOIN book_authors ba ON ba.book_id   = b.book_id
LEFT JOIN authors      a  ON a.author_id  = ba.author_id
GROUP  BY b.book_id, b.title, b.isbn, c.name
ORDER  BY total_loans DESC;


CREATE OR REPLACE VIEW vw_available_books AS
SELECT
    b.book_id,
    b.title,
    b.isbn,
    c.name AS category,
    GROUP_CONCAT(DISTINCT l.language_name SEPARATOR ', ') AS languages,  -- [1NF FIX ⑤]
    COUNT(bc.copy_id) AS available_copies
FROM   books b
JOIN   book_copies bc  ON bc.book_id    = b.book_id AND bc.is_available = 1
LEFT JOIN categories c ON c.category_id = b.category_id
LEFT JOIN book_languages bl ON bl.book_id = b.book_id
LEFT JOIN languages l      ON l.language_id = bl.language_id
GROUP  BY b.book_id, b.title, b.isbn, c.name
HAVING COUNT(bc.copy_id) > 0;


CREATE OR REPLACE VIEW vw_fine_summary AS
SELECT status, COUNT(*) AS fine_count, SUM(amount) AS total_amount
FROM fines GROUP BY status;


CREATE OR REPLACE VIEW vw_user_borrowing_history AS
SELECT
    u.user_id,
    CONCAT(u.first_name, ' ', u.last_name) AS full_name,
    b.title,
    l.loan_date,
    l.due_date,
    l.return_date,
    l.status AS loan_status,
    COALESCE(f.amount, 0) AS fine_amount,
    f.status AS fine_status
FROM   users u
JOIN   loans       l  ON l.user_id  = u.user_id
JOIN   book_copies bc ON bc.copy_id = l.copy_id
JOIN   books       b  ON b.book_id  = bc.book_id
LEFT JOIN fines    f  ON f.loan_id  = l.loan_id;


-- ============================================================
--  SAMPLE DATA  (updated for new columns)
-- ============================================================

-- Authors [1NF FIX ④]
INSERT INTO authors (first_name, last_name, nationality, birth_year) VALUES
    ('George',  'Orwell',  'British',  1903),
    ('J.K.',    'Rowling', 'British',  1965),
    ('Frank',   'Herbert', 'American', 1920),
    ('Yuval',   'Harari',  'Israeli',  1976),
    ('Robert',  'Martin',  'American', 1952);

-- Books (no language column) [1NF FIX ⑤]
INSERT INTO books (isbn, title, category_id, publisher, published_year) VALUES
    ('978-0451524935', 'Nineteen Eighty-Four',                       1, 'Secker & Warburg', 1949),
    ('978-0439708180', 'Harry Potter and the Sorcerer''s Stone',     1, 'Scholastic',        1997),
    ('978-0441013593', 'Dune',                                       1, 'Chilton Books',     1965),
    ('978-0062316097', 'Sapiens: A Brief History of Humankind',      2, 'Harper',            2011),
    ('978-0132350884', 'Clean Code',                                 5, 'Prentice Hall',     2008);

-- Book languages (each row = one atomic language per book) [1NF FIX ⑤]
INSERT INTO book_languages (book_id, language_id) VALUES
    (1, 1), (2, 1), (3, 1), (4, 1), (5, 1);  -- all English (language_id=1)

-- Book–Author roles (each row = one author in one role) [1NF FIX ⑥]
INSERT INTO book_authors (book_id, author_id, role_id) VALUES
    (1, 1, 1), (2, 2, 1), (3, 3, 1), (4, 4, 1), (5, 5, 1);  -- role_id=1 = 'Author'

-- Book copies (condition_id FK) [1NF FIX ⑦]
INSERT INTO book_copies (book_id, barcode, condition_id, location_shelf) VALUES
    (1, 'BC0001', 2, 'A1-Row1'),   -- Good
    (1, 'BC0002', 3, 'A1-Row1'),   -- Fair
    (2, 'BC0003', 1, 'A1-Row2'),   -- New
    (2, 'BC0004', 2, 'A1-Row2'),   -- Good
    (3, 'BC0005', 2, 'A2-Row1'),   -- Good
    (4, 'BC0006', 1, 'B1-Row1'),   -- New
    (4, 'BC0007', 2, 'B1-Row1'),   -- Good
    (5, 'BC0008', 2, 'C1-Row3');   -- Good

-- Users [1NF FIX ① ②]
INSERT INTO users (first_name, last_name, email,
                   street_address, city, country,
                   role, tier_id, password_hash) VALUES
    ('Alice',  'Johnson', 'alice@example.com', '12 Tahrir Sq', 'Cairo',      'Egypt', 'member',    1, '$2b$12$hash_alice'),
    ('Bob',    'Smith',   'bob@example.com',   '5 Nile Corniche','Giza',     'Egypt', 'member',    2, '$2b$12$hash_bob'),
    ('Carol',  'White',   'carol@example.com', '88 Ramses St', 'Alexandria', 'Egypt', 'member',    3, '$2b$12$hash_carol'),
    ('David',  'Admin',   'david@library.com', '1 Library Rd', 'Cairo',      'Egypt', 'librarian', 4, '$2b$12$hash_david'),
    ('Eve',    'Super',   'eve@library.com',   '1 Library Rd', 'Cairo',      'Egypt', 'admin',     4, '$2b$12$hash_eve');

-- User phones (separate table) [1NF FIX ③]
INSERT INTO user_phones (user_id, phone_number, phone_type, is_primary) VALUES
    (1, '01012345678', 'mobile', 1),
    (2, '01098765432', 'mobile', 1),
    (2, '0223456789',  'home',   0),   -- Bob has two numbers — now properly stored
    (3, '01155554444', 'mobile', 1),
    (4, '01133332222', 'work',   1),
    (5, '01177778888', 'work',   1);

-- Sample loans
INSERT INTO loans (user_id, copy_id, issued_by, loan_date, due_date, status) VALUES
    (1, 1, 4, DATE_ADD(CURRENT_DATE, INTERVAL -5 DAY),  DATE_ADD(CURRENT_DATE, INTERVAL 9 DAY),  'active'),
    (2, 6, 4, DATE_ADD(CURRENT_DATE, INTERVAL -25 DAY), DATE_ADD(CURRENT_DATE, INTERVAL -3 DAY), 'overdue');

-- Sample reservation
INSERT INTO reservations (user_id, book_id) VALUES (3, 1);

-- ============================================================
--  END OF SCRIPT
-- ============================================================