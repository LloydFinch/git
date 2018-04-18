#include "cache.h"
#include "fsexcludes.h"
#include "hashmap.h"
#include "strbuf.h"

static int fsexcludes_initialized = 0;
static struct strbuf fsexcludes_data = STRBUF_INIT;
static struct hashmap fsexcludes_hashmap;
static struct hashmap parent_directory_hashmap;

struct fsexcludes {
	struct hashmap_entry ent; /* must be the first member! */
	const char *pattern;
	int patternlen;
};

static unsigned int(*fsexcludeshash)(const void *buf, size_t len);
static int(*fsexcludescmp)(const char *a, const char *b, size_t len);

static int fsexcludes_hashmap_cmp(const void *unused_cmp_data,
	const void *a, const void *b, const void *key)
{
	const struct fsexcludes *fse1 = a;
	const struct fsexcludes *fse2 = b;

	return fsexcludescmp(fse1->pattern, fse2->pattern, fse1->patternlen);
}

static int check_fsexcludes_hashmap(struct hashmap *map, const char *pattern, int patternlen)
{
	struct strbuf sb = STRBUF_INIT;
	struct fsexcludes fse;
	char *slash;

	/* Check straight mapping */
	strbuf_add(&sb, pattern, patternlen);
	fse.pattern = sb.buf;
	fse.patternlen = sb.len;
	hashmap_entry_init(&fse, fsexcludeshash(fse.pattern, fse.patternlen));
	if (hashmap_get(map, &fse, NULL)) {
		strbuf_release(&sb);
		return 0;
	}

	/*
	 * Check to see if it matches a directory or any path
	 * underneath it.  In other words, 'a/b/foo.txt' will match
	 * '/', 'a/', and 'a/b/'.
	 */
	slash = strchr(sb.buf, '/');
	while (slash) {
		fse.pattern = sb.buf;
		fse.patternlen = slash - sb.buf + 1;
		hashmap_entry_init(&fse, fsexcludeshash(fse.pattern, fse.patternlen));
		if (hashmap_get(map, &fse, NULL)) {
			strbuf_release(&sb);
			return 0;
		}
		slash = strchr(slash + 1, '/');
	}

	strbuf_release(&sb);
	return 1;
}

static void fsexcludes_hashmap_add(struct hashmap *map, const char *pattern, const int patternlen)
{
	struct fsexcludes *fse;

	fse = xmalloc(sizeof(struct fsexcludes));
	fse->pattern = pattern;
	fse->patternlen = patternlen;
	hashmap_entry_init(fse, fsexcludeshash(fse->pattern, fse->patternlen));
	hashmap_add(map, fse);
}

static void initialize_fsexcludes_hashmap(struct hashmap *map, struct strbuf *fsexcludes_data)
{
	char *buf, *entry;
	size_t len;
	int i;

	/*
	 * Build a hashmap of the fsexcludes data we can use to look
	 * for cache entry matches quickly
	 */
	fsexcludeshash = ignore_case ? memihash : memhash;
	fsexcludescmp = ignore_case ? strncasecmp : strncmp;
	hashmap_init(map, fsexcludes_hashmap_cmp, NULL, 0);

	entry = buf = fsexcludes_data->buf;
	len = fsexcludes_data->len;
	for (i = 0; i < len; i++) {
		if (buf[i] == '\0') {
			fsexcludes_hashmap_add(map, entry, buf + i - entry);
			entry = buf + i + 1;
		}
	}
}

static void parent_directory_hashmap_add(struct hashmap *map, const char *pattern, const int patternlen)
{
	char *slash;
	struct fsexcludes *fse;

	/*
	 * Add any directories leading up to the file as the excludes logic
	 * needs to match directories leading up to the files as well. Detect
	 * and prevent unnecessary duplicate entries which will be common.
	 */
	if (patternlen > 1) {
		slash = strchr(pattern + 1, '/');
		while (slash) {
			fse = xmalloc(sizeof(struct fsexcludes));
			fse->pattern = pattern;
			fse->patternlen = slash - pattern + 1;
			hashmap_entry_init(fse, fsexcludeshash(fse->pattern, fse->patternlen));
			if (hashmap_get(map, fse, NULL))
				free(fse);
			else
				hashmap_add(map, fse);
			slash = strchr(slash + 1, '/');
		}
	}
}

static void initialize_parent_directory_hashmap(struct hashmap *map, struct strbuf *vfs_data)
{
	char *buf, *entry;
	size_t len;
	int i;

	/*
	 * Build a hashmap of the parent directories contained in the virtual
	 * file system data we can use to look for matches quickly
	 */
	fsexcludeshash = ignore_case ? memihash : memhash;
	fsexcludescmp = ignore_case ? strncasecmp : strncmp;
	hashmap_init(map, fsexcludes_hashmap_cmp, NULL, 0);

	entry = buf = vfs_data->buf;
	len = vfs_data->len;
	for (i = 0; i < len; i++) {
		if (buf[i] == '\0') {
			parent_directory_hashmap_add(map, entry, buf + i - entry);
			entry = buf + i + 1;
		}
	}
}

static int check_directory_hashmap(struct hashmap *map, const char *pathname, int pathlen)
{
	struct strbuf sb = STRBUF_INIT;
	struct fsexcludes fse;

	/* Check for directory */
	strbuf_add(&sb, pathname, pathlen);
	strbuf_addch(&sb, '/');
	fse.pattern = sb.buf;
	fse.patternlen = sb.len;
	hashmap_entry_init(&fse, fsexcludeshash(fse.pattern, fse.patternlen));
	if (hashmap_get(map, &fse, NULL)) {
		strbuf_release(&sb);
		return 0;
	}

	strbuf_release(&sb);
	return 1;
}

/*
 * Return 1 for exclude, 0 for include and -1 for undecided.
 */
int fsexcludes_is_excluded_from(struct index_state *istate,
	const char *pathname, int pathlen, int dtype)
{
	if (!fsexcludes_initialized)
		return -1;

	if (dtype == DT_REG) {
		/* lazily init the hashmap */
		if (!fsexcludes_hashmap.cmpfn_data)
			initialize_fsexcludes_hashmap(&fsexcludes_hashmap, &fsexcludes_data);

		return check_fsexcludes_hashmap(&fsexcludes_hashmap, pathname, pathlen);
	}

	if (dtype == DT_DIR || dtype == DT_LNK) {
		/* lazily init the hashmap */
		if (!parent_directory_hashmap.cmpfn_data)
			initialize_parent_directory_hashmap(&parent_directory_hashmap, &fsexcludes_data);

		return check_directory_hashmap(&parent_directory_hashmap, pathname, pathlen);
	}

	return -1;
}

void fsexcludes_init(struct strbuf *sb)
{
	fsexcludes_initialized = 1;
	fsexcludes_data = *sb;
	strbuf_detach(sb, NULL);
}

void fsexcludes_free(void) {
	strbuf_release(&fsexcludes_data);
	hashmap_free(&fsexcludes_hashmap, 1);
	hashmap_free(&parent_directory_hashmap, 1);
	fsexcludes_initialized = 0;
}
