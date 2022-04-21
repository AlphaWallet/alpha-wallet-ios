The chains.json file is downloaded from https://chainid.network/chains.json.

This file is then compressed using NSData.CompressionAlgorithm.lzma and stored raw without any headers.

It is then renamed as chains.zip and must be added to the Rpc Network group of the project.

A Makefile target has been added to automate this process. At the command line, type in:

```
make update_chains_file
```

and you should see the following response:

```console
Deleting chains file in scripts folder.
Downloading chains file.
################################################################################################################# 100.0%
Compressing.
Moving compressed file into project.
Update completed.
```
