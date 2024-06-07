package models

import (
	"database/sql"
	"errors"
	"time"
)

type Product struct {
	ID      int
	Title   string
	Content string
	Created time.Time
	Expires time.Time
}

type ProductModelInterface interface {
	Insert(title string, content string, expires int) (int, error)
	Get(id int) (*Product, error)
	Latest() ([]*Product, error)
}

type ProductModel struct {
	DB *sql.DB
}

func (m *ProductModel) Insert(title string, content string, expires int) (int, error) {
	stmt := `INSERT INTO products (title, content, created, expires) VALUES(?, ?, UTC_TIMESTAMP(), DATE_ADD(UTC_TIMESTAMP(), INTERVAL ? DAY))`

	result, err := m.DB.Exec(stmt, title, content, expires)
	if err != nil {
		return 0, err
	}

	id, err := result.LastInsertId()
	if err != nil {
		return 0, err
	}

	return int(id), nil
}

func (m *ProductModel) Get(id int) (*Product, error) {
	s := &Product{}

	err := m.DB.QueryRow("SELECT id, title, content, created, expires FROM products WHERE expires > UTC_TIMESTAMP() AND id = ?", id).Scan(&s.ID, &s.Title, &s.Content, &s.Created, &s.Expires)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrNoRecord
		} else {
			return nil, err
		}
	}

	return s, nil
}

func (m *ProductModel) Latest() ([]*Product, error) {
	stmt := `SELECT id, title, content, created, expires FROM products WHERE expires > UTC_TIMESTAMP() ORDER BY id DESC LIMIT 10`

	rows, err := m.DB.Query(stmt)
	if err != nil {
		return nil, err
	}

	defer rows.Close()

	products := []*Product{}

	for rows.Next() {
		s := &Product{}

		err = rows.Scan(&s.ID, &s.Title, &s.Content, &s.Created, &s.Expires)
		if err != nil {
			return nil, err
		}

		products = append(products, s)
	}

	if err = rows.Err(); err != nil {
		return nil, err
	}

	return products, nil
}
