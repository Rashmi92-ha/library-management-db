# Library Management Database System

A relational database in MySQL for managing books, users, and book transactions. It includes stored procedures for issuing and returning books, plus queries and views for tracking overdue books, borrowing history, and fines.

## Features

- Three related tables (Users, Books, Transactions) linked by foreign keys
- `CHECK` constraints that stop copy counts going negative or above the total, and limit status to `ISSUED` or `RETURNED`
- `issue_book` and `return_book` stored procedures that keep `available_copies` in sync, using transactions and row locking
- Tracking queries: overdue books, user borrowing history, most borrowed books, users holding the most books
- Views for current issues and overdue fines (Rs. 2 per day)
- An index on `Transactions(status, due_date)` for faster filtering

## Requirements

- MySQL **8.0.16 or newer** (older versions ignore `CHECK` constraints)
- Any MySQL client, such as MySQL Workbench or the `mysql` command line

## How to Run

1. Clone the repository:
   ```
   git clone https://github.com/Rashmi92-ha/library-management-db.git
   ```
2. Open `library_management.sql` in MySQL Workbench.
3. Run the whole script (Ctrl+Shift+Enter).

The script drops and recreates the `library_management` database each time, so it is safe to re-run.

## Database Schema

**Users**

| Column | Type | Notes |
|---|---|---|
| user_id | INT | Primary key, auto increment |
| name | VARCHAR(100) | Required |
| email | VARCHAR(150) | Required, unique |
| phone | VARCHAR(20) | |
| membership_date | DATE | Defaults to today |

**Books**

| Column | Type | Notes |
|---|---|---|
| book_id | INT | Primary key, auto increment |
| title | VARCHAR(100) | Required |
| author | VARCHAR(150) | Required |
| category | VARCHAR(100) | |
| isbn | VARCHAR(20) | Unique |
| total_copies | INT | Must be 0 or more |
| available_copies | INT | Must be between 0 and total_copies |

**Transactions**

| Column | Type | Notes |
|---|---|---|
| transaction_id | INT | Primary key, auto increment |
| user_id | INT | Foreign key to Users |
| book_id | INT | Foreign key to Books |
| issue_date | DATE | Defaults to today |
| due_date | DATE | Required |
| return_date | DATE | Empty until the book is returned |
| status | VARCHAR(20) | `ISSUED` or `RETURNED` |

**Relationships:** one user can have many transactions, and one book can appear in many transactions.

## Usage

**Issue a book** (user 1 borrows book 5). This creates a transaction due in 14 days and reduces `available_copies` by 1:

```sql
CALL issue_book(1, 5);
```

**Return a book** (user 1 returns book 5). This marks the transaction `RETURNED` and increases `available_copies` by 1:

```sql
CALL return_book(1, 5);
```

**Error handling.** The procedures raise clear errors for:

- `User does not exist`
- `Book does not exist`
- `No copies available`
- `No issued book found for this user`

## Example Queries

**Overdue books:**

```sql
SELECT u.name, b.title, t.due_date,
       DATEDIFF(CURRENT_DATE, t.due_date) AS days_overdue
FROM Transactions t
JOIN Users u ON t.user_id = u.user_id
JOIN Books b ON t.book_id = b.book_id
WHERE t.status = 'ISSUED' AND t.due_date < CURRENT_DATE;
```

**Current issues and fines, using the views:**

```sql
SELECT * FROM vw_current_issues;
SELECT * FROM vw_overdue_fines;
```

The script also includes queries for borrowing history, most borrowed books, and users currently holding the most books.

## Notes

- The sample data uses fixed dates in September and October 2026, so which books count as overdue depends on the date you run the queries.
- All names, emails, and phone numbers in the sample data are made up.

## Skills Demonstrated

Relational design, primary and foreign keys, constraints, joins, aggregation, stored procedures, transactions and row locking, views, and indexing.
