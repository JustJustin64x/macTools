#include "FinderKeys.h"
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv) {
    bool check = false, verbose = false;
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--self-test")) return finder_keys_self_test();
        if (!strcmp(argv[i], "--check")) check = true;
        else if (!strcmp(argv[i], "--verbose")) verbose = true;
        else { fprintf(stderr, "Aufruf: finder_keys [--check | --self-test | --verbose]\n"); return 2; }
    }
    return finder_keys_run(verbose, check);
}
