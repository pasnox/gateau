file(APPEND ${QWT_CONFIG_FILE} "QWT_CONFIG -= QwtSvg QwtOpenGL QwtDesigner QwtDll QwtMathML QwtExamples QwtPlayground\n")
file(APPEND ${QWT_CONFIG_FILE} "QWT_INSTALL_PREFIX = \"${QWT_INSTALL_DIR}\"\n")
file(APPEND ${QWT_CONFIG_FILE} "QWT_INSTALL_HEADERS = \"${QWT_INSTALL_DIR}/include/qwt\"\n")
file(APPEND ${QWT_CONFIG_FILE} "QWT_INSTALL_LIBS = \"${QWT_INSTALL_DIR}/lib\"\n")
file(APPEND ${QWT_CONFIG_FILE} "QWT_INSTALL_DOCS = \"${QWT_INSTALL_DIR}/share/doc/qwt\"\n")
file(APPEND ${QWT_CONFIG_FILE} "QWT_INSTALL_PLUGINS = \"${QWT_INSTALL_DIR}/lib/qt5/plugins\"\n")
file(APPEND ${QWT_CONFIG_FILE} "QWT_INSTALL_FEATURES = \"${QWT_INSTALL_DIR}/lib/qt5/mkspecs/features\"\n")
