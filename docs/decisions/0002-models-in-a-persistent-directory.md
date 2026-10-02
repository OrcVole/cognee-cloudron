# ADR-0002: the downloaded models live in a persistent directory

**Status:** accepted.

**Context.** The two local models total about 812 MB and download on first use. Baking them into the image makes
them stale on the day of release. Keeping them in `/app/data` put them in every backup: 418 MB of backup for about
2 MB of user data.

**Decision.** Download on first use (a checklist item in the manifest tells the operator) into `/app/models`, a
`persistentDirs` entry. `HF_HOME` and `FASTEMBED_CACHE_PATH` point there. The platform keeps it across updates
and leaves it out of backups. `start.sh` removes any older `/app/data/models` copy so an updated install sheds it.

**Consequences.** Measured on a test box: after an in-place update the old directory is gone and the new one
exists; a backup is a fraction of its former size; a restore leaves the model folder as it was; a clone starts
with it empty and refills on its first `cognify`. A restore onto a new server therefore needs outbound internet
once.
