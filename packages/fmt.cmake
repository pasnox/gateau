#set(fmt_VERSION "7.0.1")
#set(fmt_URL "https://github.com/fmtlib/fmt/archive/${fmt_VERSION}.tar.gz")
set(fmt_GIT "https://github.com/fmtlib/fmt")
#set(fmt_MD5 "0cafa0aa67c0e28e9d79a2ebf8fc7732")
set(fmt_CMAKE_ARGS
    -DFMT_DOC=OFF
    -DFMT_TEST=OFF
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON
    -DFMT_HEADER_ONLY=ON
    -DFMT_ARM_ABI_COMPATIBILITY=ON
)
