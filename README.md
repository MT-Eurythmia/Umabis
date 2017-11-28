# Umabis

Ultimate Minetest Authentication, Banning and Identity theft prevention System

## Installing

The mod depends on LuaSocket:
```
# apt-get install luarocks
# luarocks install luasocket
```

For HTTPS support (**highly recommended** on production), you will also need
the LuaSec package:
```
# luarocks install luasec
```

## Version numbering convention

Both client and server version are represented using three numbers `a.b.c`:

|`a` | `b` | `c`|
|----|-----|----|
|Breaking change. If server `a` and client `a` are not equal, they will not be able to negociate.|New server feature. If client `b` is lower than server `b`, it may not be able to benefit a few non-essential server features.|Minor update (such as a bugfix).|
