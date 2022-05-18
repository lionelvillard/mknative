package main

import (
    "fmt"
    "io"
    "log"
    "net/http"
)

func handle(w http.ResponseWriter, req *http.Request) {
    fmt.Printf("Remote Address: %s\n", req.RemoteAddr)


    for k, v := range req.Header {
        fmt.Printf("%s=%s\n", k, v[0])
    }


    body, err := io.ReadAll(req.Body)
    if err != nil {
        log.Println(err)
        return
    }
    defer req.Body.Close()
    fmt.Println(string(body))
}

func main() {
    http.HandleFunc("/", handle)
    if err := http.ListenAndServe(":8080", nil); err != nil {
        log.Fatal(err)
    }
}
