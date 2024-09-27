# nginx-webdav

Simple nginx image for serving static files over HTTP and managing them using WebDAV using `USERNAME` and `PASSWORD` environ variables. `NAME` variable allows customizing the displayed name/title.

`index`.html is not used as index, as the goal is to list files. If an index is actually wanted, use a `.drive_index.html` file
