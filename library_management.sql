-- =====================================================================
-- Library Management Database System
-- Requires MySQL 8.0.16 or newer (CHECK constraints, DEFAULT (CURRENT_DATE))
-- =====================================================================

DROP DATABASE IF EXISTS library_management;
CREATE DATABASE library_management;
USE library_management;


-- =====================================================================
-- 1. SCHEMA
-- =====================================================================

CREATE TABLE Users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    phone VARCHAR(20),
    membership_date DATE NOT NULL DEFAULT (CURRENT_DATE)
);

CREATE TABLE Books (
    book_id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    author VARCHAR(150) NOT NULL,
    category VARCHAR(100),
    isbn VARCHAR(20) UNIQUE,
    total_copies INT NOT NULL DEFAULT 1,
    available_copies INT NOT NULL DEFAULT 1,

    CHECK (total_copies >= 0),
    CHECK (available_copies >= 0),
    CHECK (available_copies <= total_copies)
);

CREATE TABLE Transactions (
    transaction_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    book_id INT NOT NULL,
    issue_date DATE NOT NULL DEFAULT (CURRENT_DATE),
    due_date DATE NOT NULL,
    return_date DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'ISSUED',

    CHECK (status IN ('ISSUED', 'RETURNED')),
    FOREIGN KEY (user_id) REFERENCES Users(user_id),
    FOREIGN KEY (book_id) REFERENCES Books(book_id)
);


-- =====================================================================
-- 2. SAMPLE DATA
-- =====================================================================

INSERT INTO Users (name, email, phone)
VALUES
('Rashmi',  'rashmi@example.com',  '9000000001'),
('Chethan', 'chethan@example.com', '9000000002'),
('Priya',   'priya@example.com',   '9000000003'),
('Sneha',   'sneha@example.com',   '9000000004');

INSERT INTO Books
    (title, author, category, isbn, total_copies, available_copies)
VALUES
('Clean Code', 'Robert C. Martin', 'Programming', '9780132350884', 5, 5),
('Java: The Complete Reference', 'Herbert Schildt', 'Programming', '9781260440232', 3, 3),
('The Alchemist', 'Paulo Coelho', 'Fiction', '9780061122415', 4, 4),
('Database System Concepts', 'Abraham Silberschatz', 'Database', '9780078022159', 2, 2),
('The Hobbit', 'J.R.R. Tolkien', 'Fantasy', '9780547928227', 3, 3);

INSERT INTO Transactions
    (user_id, book_id, issue_date, due_date, return_date, status)
VALUES
(1, 1, '2026-09-25', '2026-10-09', NULL, 'ISSUED'),
(2, 2, '2026-09-10', '2026-09-24', NULL, 'ISSUED'),
(3, 3, '2026-09-20', '2026-10-04', '2026-09-27', 'RETURNED'),
(4, 4, '2026-09-28', '2026-10-12', NULL, 'ISSUED');

-- Sync copy counts with the 3 books that are currently issued
UPDATE Books
SET available_copies = available_copies - 1
WHERE book_id IN (1, 2, 4);


-- =====================================================================
-- 3. PROCEDURES: issue_book, return_book
-- =====================================================================

DELIMITER $$

CREATE PROCEDURE issue_book(IN p_user_id INT, IN p_book_id INT)
BEGIN
    DECLARE v_available INT;
    DECLARE v_user_exists INT;

    -- Check the user exists before opening a transaction
    SELECT COUNT(*) INTO v_user_exists
    FROM Users
    WHERE user_id = p_user_id;

    IF v_user_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'User does not exist';
    END IF;

    START TRANSACTION;

    -- Lock the row so two people can't take the last copy at once
    SELECT available_copies INTO v_available
    FROM Books
    WHERE book_id = p_book_id
    FOR UPDATE;

    IF v_available IS NULL THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Book does not exist';

    ELSEIF v_available <= 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No copies available';

    ELSE
        INSERT INTO Transactions (user_id, book_id, due_date)
        VALUES (p_user_id, p_book_id, DATE_ADD(CURRENT_DATE, INTERVAL 14 DAY));

        UPDATE Books
        SET available_copies = available_copies - 1
        WHERE book_id = p_book_id;

        COMMIT;
    END IF;
END$$

CREATE PROCEDURE return_book(IN p_user_id INT, IN p_book_id INT)
BEGIN
    DECLARE v_transaction_id INT;

    START TRANSACTION;

    SELECT transaction_id INTO v_transaction_id
    FROM Transactions
    WHERE user_id = p_user_id
      AND book_id = p_book_id
      AND status = 'ISSUED'
    LIMIT 1
    FOR UPDATE;

    IF v_transaction_id IS NULL THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No issued book found for this user';

    ELSE
        UPDATE Transactions
        SET return_date = CURRENT_DATE,
            status = 'RETURNED'
        WHERE transaction_id = v_transaction_id;

        UPDATE Books
        SET available_copies = available_copies + 1
        WHERE book_id = p_book_id;

        COMMIT;
    END IF;
END$$

DELIMITER ;


-- =====================================================================
-- 4. TESTING THE PROCEDURES
-- =====================================================================

-- Issue The Hobbit to Rashmi: available copies should drop from 3 to 2
CALL issue_book(1, 5);

SELECT book_id, title, total_copies, available_copies
FROM Books
WHERE book_id = 5;

SELECT transaction_id, user_id, book_id, issue_date, due_date, return_date, status
FROM Transactions
WHERE user_id = 1 AND book_id = 5;

-- Return it: available copies should go back to 3, status becomes RETURNED
CALL return_book(1, 5);

SELECT * FROM Transactions
WHERE transaction_id = 5;

SELECT book_id, title, total_copies, available_copies
FROM Books
WHERE book_id = 5;

-- Error cases. Each one stops the script with an error, so they are
-- commented out. Run them one at a time to check the messages.
-- CALL return_book(1, 5);   -- "No issued book found for this user"
-- CALL issue_book(1, 99);   -- "Book does not exist"
-- CALL issue_book(99, 1);   -- "User does not exist"


-- =====================================================================
-- 5. TRACKING QUERIES
-- =====================================================================

-- 5.1 All transactions with user and book names
SELECT
    u.name,
    b.title,
    t.issue_date,
    t.due_date,
    t.return_date,
    t.status
FROM Transactions t
JOIN Users u ON t.user_id = u.user_id
JOIN Books b ON t.book_id = b.book_id;

-- 5.2 Books currently issued
SELECT
    u.name AS user_name,
    b.title AS book_title,
    t.issue_date,
    t.due_date,
    t.status
FROM Transactions t
JOIN Users u ON t.user_id = u.user_id
JOIN Books b ON t.book_id = b.book_id
WHERE t.status = 'ISSUED';

-- 5.3 Stock levels
SELECT book_id, title, total_copies, available_copies
FROM Books;

-- 5.4 Books currently available
SELECT title, author, available_copies
FROM Books
WHERE available_copies > 0;

-- 5.5 Overdue books
SELECT
    u.name,
    b.title,
    t.issue_date,
    t.due_date,
    DATEDIFF(CURRENT_DATE, t.due_date) AS days_overdue
FROM Transactions t
JOIN Users u ON t.user_id = u.user_id
JOIN Books b ON t.book_id = b.book_id
WHERE t.status = 'ISSUED'
  AND t.due_date < CURRENT_DATE;

-- 5.6 Borrowing history of one user (change the user_id as needed)
SELECT
    b.title,
    t.issue_date,
    t.due_date,
    t.return_date,
    t.status
FROM Transactions t
JOIN Books b ON t.book_id = b.book_id
WHERE t.user_id = 1
ORDER BY t.issue_date DESC;

-- 5.7 Most borrowed books
SELECT
    b.title,
    COUNT(*) AS times_issued
FROM Transactions t
JOIN Books b ON t.book_id = b.book_id
GROUP BY b.book_id, b.title
ORDER BY times_issued DESC, b.title;

-- 5.8 Users with the most books currently out
SELECT
    u.name,
    COUNT(*) AS books_held
FROM Transactions t
JOIN Users u ON t.user_id = u.user_id
WHERE t.status = 'ISSUED'
GROUP BY u.user_id, u.name
ORDER BY books_held DESC, u.name;


-- =====================================================================
-- 6. VIEWS AND INDEX
-- =====================================================================

-- Every book currently out, with days overdue (0 if not late)
CREATE VIEW vw_current_issues AS
SELECT
    t.transaction_id,
    u.name AS user_name,
    b.title AS book_title,
    t.issue_date,
    t.due_date,
    GREATEST(DATEDIFF(CURRENT_DATE, t.due_date), 0) AS days_overdue
FROM Transactions t
JOIN Users u ON t.user_id = u.user_id
JOIN Books b ON t.book_id = b.book_id
WHERE t.status = 'ISSUED';

-- Overdue books with fine at Rs. 2 per day
CREATE VIEW vw_overdue_fines AS
SELECT
    t.transaction_id,
    u.name AS user_name,
    b.title AS book_title,
    t.due_date,
    DATEDIFF(CURRENT_DATE, t.due_date) AS days_overdue,
    DATEDIFF(CURRENT_DATE, t.due_date) * 2 AS fine_amount
FROM Transactions t
JOIN Users u ON t.user_id = u.user_id
JOIN Books b ON t.book_id = b.book_id
WHERE t.status = 'ISSUED'
  AND t.due_date < CURRENT_DATE;

-- Speeds up status and due-date filtering (user_id and book_id are
-- already indexed automatically through their foreign keys)
CREATE INDEX idx_transactions_status_due
ON Transactions (status, due_date);

-- Try the views
SELECT * FROM vw_current_issues;
SELECT * FROM vw_current_issues WHERE days_overdue > 0;
SELECT * FROM vw_overdue_fines;
SELECT SUM(fine_amount) AS total_fines FROM vw_overdue_fines;

SHOW INDEX FROM Transactions;