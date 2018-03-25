set(CMAKE_SHARED_LIBRARY_SUFFIX ".so")
set(CMAKE_STATIC_LIBRARY_SUFFIX ".a")
set(PKG_CONFIG_EXECUTABLE "pkg-config")

include("CheckLinkModePkgConfig.cmake")

# GET_LIST_REQ_PKGS("mirclient" pkg_reqs)
set(libnames "/usr/lib/x86_64-linux-gnu/libmirclient.so;/usr/lib/x86_64-linux-gnu/libmircore.so;/usr/lib/x86_64-linux-gnu/libpthread.so;/usr/lib/libc.so;/usr/lib/libm.so")
FIND_PKG_FROM_LIBPATH_LIST("mirclient" "${libnames}" libnames_ FALSE is_found is_static)
message("${libnames_}")
message(${is_found})
message(${is_static})
