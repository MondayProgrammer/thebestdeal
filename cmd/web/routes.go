package main

import (
	"net/http"

	"github.com/julienschmidt/httprouter"
	"github.com/justinas/alice"
	"thebestdeal.net/ui"
)

// func (app *application) routes() http.Handler {
// 	mux := http.NewServeMux()

// 	fileServer := http.FileServer(http.Dir("./ui/static/"))
// 	mux.Handle("/static/", http.StripPrefix("/static", fileServer))

// 	mux.HandleFunc("/", app.home)
// 	mux.HandleFunc("/product/view", app.productView)
// 	mux.HandleFunc("/product/create", app.productCreate)

// 	// return app.recoverPanic(app.logRequest(secureHeaders(mux)))

// 	standart := alice.New(app.recoverPanic, app.logRequest, secureHeaders)

// 	return standart.Then(mux)
// }

func (app *application) routes() http.Handler {
	router := httprouter.New()

	router.NotFound = http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		app.notFound(w)
	})

	// fileServer := http.FileServer(http.Dir("./ui/static/"))
	// router.Handler(http.MethodGet, "/static/*filepath", http.StripPrefix("/static", fileServer))
	fileServer := http.FileServer(http.FS(ui.Files))
	router.Handler(http.MethodGet, "/static/*filepath", fileServer)

	router.HandlerFunc(http.MethodGet, "/ping", ping)

	dynamic := alice.New(app.sessionManager.LoadAndSave, noSurf, app.authenticate)

	// router.HandlerFunc(http.MethodGet, "/", app.home)
	// router.HandlerFunc(http.MethodGet, "/product/view/:id", app.productView)
	// router.HandlerFunc(http.MethodGet, "/product/create", app.productCreate)
	// router.HandlerFunc(http.MethodPost, "/product/create", app.productCreatePost)
	router.Handler(http.MethodGet, "/", dynamic.ThenFunc(app.home))
	router.Handler(http.MethodGet, "/about", dynamic.ThenFunc(app.about))
	router.Handler(http.MethodGet, "/product/view/:id", dynamic.ThenFunc(app.productView))
	router.Handler(http.MethodGet, "/user/signup", dynamic.ThenFunc(app.userSignup))
	router.Handler(http.MethodPost, "/user/signup", dynamic.ThenFunc(app.userSignupPost))
	router.Handler(http.MethodGet, "/user/login", dynamic.ThenFunc(app.userLogin))
	router.Handler(http.MethodPost, "/user/login", dynamic.ThenFunc(app.userLoginPost))

	protected := dynamic.Append(app.requireAuthentication)

	router.Handler(http.MethodGet, "/product/create", protected.ThenFunc(app.productCreate))
	//router.Handler(http.MethodPost, "/product/create", app.sessionManager.LoadAndSave(app.requireAuthentication(http.HandlerFunc(app.productCreate))))
	router.Handler(http.MethodPost, "/product/create", protected.ThenFunc(app.productCreatePost))
	router.Handler(http.MethodGet, "/account/view", protected.ThenFunc(app.accountView))
	router.Handler(http.MethodGet, "/account/password/update", protected.ThenFunc(app.accountPasswordUpdate))
	router.Handler(http.MethodPost, "/account/password/update", protected.ThenFunc(app.accountPasswordUpdatePost))
	router.Handler(http.MethodPost, "/user/logout", protected.ThenFunc(app.userLogoutPost))

	standard := alice.New(app.recoverPanic, app.logRequest, secureHeaders)
	return standard.Then(router)
}
