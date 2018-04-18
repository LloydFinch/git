#ifndef FSEXCLUDES_H
#define FSEXCLUDES_H

/*
 * The file system excludes functions provides a way to programatically limit
 * where git will scan for untracked files.  This is used to speed up the
 * scan by avoiding scanning parts of the work directory that do not have
 * any new files.
 */

/*
 * sb should contain a NUL separated list of path names of the files
 * and/or directories that should be checked.  Any path not listed will
 * be excluded from the scan.
 *
 * NOTE: fsexcludes_init() will take ownership of the storage passed in
 * sb and will reset sb to `STRBUF_INIT`
 */
void fsexcludes_init(struct strbuf *sb);
void fsexcludes_free(void);

/*
 * Return 1 for exclude, 0 for include and -1 for undecided.
 */
int fsexcludes_is_excluded_from(struct index_state *istate,
	const char *pathname, int pathlen, int dtype_p);


#endif
