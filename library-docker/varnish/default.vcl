vcl 4.0;

acl purge {
    "localhost";
}

backend default {  
    .host = "localhost";
    .port = "8000";

    # .connect_timeout = 60s;
    # .first_byte_timeout = 60s;
    # .between_bytes_timeout = 60s;
}

sub vcl_recv {
    # allow HTTP purge
    # curl -X PURGE http://localhost/xxx to remove resource xxx from cache
    if (req.method == "PURGE") {
        if (!client.ip ~ purge) {
            return(synth(405, "Not allowed."));
        }
        return (purge);
    }

    # set standard proxied ip header for getting original remote address
    set req.http.X-Forwarded-For = client.ip;

    # cache / (homepage)
    # cache /skin/ (kiwix-serve toolbar)
    # cache /meta?content=xxxxxx&name=favicon (homepage favicons)
    # cache /catalog (OPDS)
    if (req.url ~ "^/$" || 
        req.url ~ "^/skin/" || 
        req.url ~ "^/meta\?content=[a-z0-9\-\_]+&name=favicon" ||
        req.url ~ "^/catalog/") {
        return(hash);
    }

    # default to not caching (to save space)
    return (pass);
}

sub vcl_backend_response {
    
    # kiwix-serve doesn't set cache-friendly headers (Cache-control: nocache)
    # caching toolbar, catalog and homepage for 1d
    if (bereq.url ~ "^/$" ||
        bereq.url ~ "^/skin/" || 
        bereq.url ~ "^/catalog/") {
        unset beresp.http.set-cookie;
        unset beresp.http.Cache-Control;
        unset beresp.http.Age;
        set beresp.ttl = 1d;
    }
}
