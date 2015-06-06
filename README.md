server-logparser
================

Little script to parse a folder of logfiles and upload them.

# Prequests

- lua

## Libraries
- penlight
- dkjson
- luarocks

# Install

You might want to install these locally

```sh
sudo whateverpackagemanager install lua luarocks
sudo luarocks install penlight
sudo luarocks install dkjson
sudo luarocks install luarocks
```

# Usage 

```sh
lua logparser.lua logs http://localhost:9000/api
```
