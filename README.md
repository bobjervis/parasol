# parasol
The Parasol Language and related core development tools

Documentation can be obtained by cloning the repository to a Linux directory, then in the repo directory issue the following shell command:

```bash
bin/paradoc -c doc/parasol ~/paradoc
```

Thus will generate a set of HTML pages under a (presumably new) directory named `paradoc` in your home directory. You can, of course, substitute any other directory name you wish, but if you name an existing directory the `paradoc` utility will over-write those contents, effectively deleting them and replacing them with the HTML files.

You may then run the following command:

```bash
sudo bin/phost --localhost ~/paradoc &
```

Note that this will default to port 80.


In a browser, you can then enter the URL:

```
http://localhost
```

Which will bring up the top-level page of the documentation suite, which is quite patchy, although the runtime documentation is 
fairly complete.

Because port 80 requires root permissions to open, you must run this command under `sudo`. If you are already hosting another server on that port or you don't want to use `sudo`, you can add a `--port=<number>` option to the command line. For example, if you want to use port 8080, use this:

```bash
bin/phost --port=8080 --localhost ~/paradoc &
```

You will then use the following url:

```
http://localhost:8080
```

