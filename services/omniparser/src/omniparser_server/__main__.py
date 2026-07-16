import uvicorn

if __name__ == "__main__":
    uvicorn.run("omniparser_server.server:app", host="127.0.0.1", port=8200, reload=False)
