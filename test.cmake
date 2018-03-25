set(CMAKE_SHARED_LIBRARY_SUFFIX ".so")
set(CMAKE_STATIC_LIBRARY_SUFFIX ".a")
set(PKG_CONFIG_EXECUTABLE "pkg-config")

include("CheckLinkModePkgConfig.cmake")

# GET_LIST_REQ_PKGS("mirclient" pkg_reqs)
set(libnames "/usr/lib/x86_64-linux-gnu/libmirclient.so;/usr/lib/x86_64-linux-gnu/libmircore.so;/usr/lib/x86_64-linux-gnu/libpthread.so;/usr/lib/libc.so;/usr/lib/libm.so")
CHECK_PKG_LINKMODE("mirclient" "${libnames}" libnames_ link_mode)
CHECK_PKG_LINKMODE("oe" "${libnames}" libnames_ link_mode)
message("${libnames_}")
