package data

import (
	"database/sql"
	"errors"
)

var (
	ErrRecordNotFound = errors.New("record not found")
	ErrEditConflict   = errors.New("edit conflict")
)

type Models struct {
	// page 139
	// Set the Movies field to be an interface containing the methods that both the
	// 'real' model and mock model need to support.
	// Movies interface {
	// 	Insert(movie *Movie) error
	// 	Get(id int64) (*Movie, error)
	// 	Update(movie *Movie) error
	// 	Delete(id int64) error
	// }
	Movies      MovieModel
	Permissions PermissionModel
	Tokens      TokenModel
	Users       UserModel
}

func NewModels(db *sql.DB) Models {
	return Models{
		Movies:      MovieModel{DB: db},
		Permissions: PermissionModel{DB: db},
		Tokens:      TokenModel{DB: db},
		Users:       UserModel{DB: db},
	}
}
