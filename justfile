DIST_DIRS := (
    "node_modules"
    + " releases"
)

distclean:
    rm -rf {{DIST_DIRS}}
