# Umabis

Ultimate Minetest Authentication, Banning and Identity theft prevention System

## Installing

### Dependencies

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

### Configuring

Once you have installed the dependencies, added the mod in your mods directory
and enabled it in your `world.mt`, you need to configure it.

Everything can be set in `minetest.conf`, prefixing settings names with `umabis.`.

You can find an exhaustive list of settings in the `default_settings.conf` file,
but most of them have sensible default values and you'll probably need to change
only three of them:

* `umabis.api_uri`: set this to the URI of your Umabis server, and add `api/`
at the end. The protocol needs to be explicitely written (`http` or `https`),
and it would be an extremely bad idea to run a production server without `https`,
as passwords would be sent in clear text.
* `umabis.server_name` and `umabis.server_password`: the information that allow
your minetest server to be authenticated by the Umabis server (see
[Setting up the database](https://github.com/MT-Eurythmia/Umabis_server/blob/master/README.md#setting-up-the-database)).

Start the minetest server and check the logs. If everything is going well,
try to join the server and to register. Now, you can [make yourself the first
admin](https://github.com/MT-Eurythmia/Umabis_server/blob/master/README.md#creating-the-first-admin).

## Version numbering convention

Both client and server version are represented using three numbers `a.b.c`:

|`a` | `b` | `c`|
|----|-----|----|
|Breaking change. If server `a` and client `a` are not equal, they will not be able to negociate.|New server feature. If client `b` is lower than server `b`, it may not be able to benefit a few non-essential server features.|Minor update (such as a bugfix).|
