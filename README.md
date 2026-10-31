# EVC

EVC is a wrapper for Git that exposes easier syntax for the most typical workflows, automatically taking care of Git specifics like committing, staging, rebasing, squashing, etc. It's easy to use for beginners as well as a handy utility for experienced developers, and the Git commands it runs under the hood are straightforward translations if you ever need to use more involved Git functionality or debug. (In fact, EVC prints the full hidden Git command output to a `.evc/logs/` folder in the project.)

## For Beginners New to Git

Say you want to contribute to a project. You want to implement a feature, but you also in the mean time want to work on a different feature, even though the features conflict (change the same lines of code differently.) You basically want two copies of the project, one for each feature. *Version control* automatically takes care of this, but instead of copying everything fully, it uses sophisticated algorithms to optimize for space (and speed) and get the same effect. This is why version control is very popular for software development. Git is one of the most popular version control systems, but the syntax for working with Git is notoriously difficult. This is where EVC helps.

Before laying out how to use EVC, some terminology:

- A Git-based project is called a *repository*, or *repo* for short. Different features/versions of the repo are called *branches*. The original branch is often named *main* (it might be different for some existing repos, but "main" is the default for new repos on popular Git-based platforms like GitHub.)

- A typical workflow is to treat main as the "final correct" state: you work in a non-main branch (also called a *feature branch*) to make progress on a feature, and once it's done you *merge* it to main. That way, main has all the "final correct" feature functionality.

- To contribute to an existing repo: first, it would be hosted on a platform that others can access (like GitHub.) You would then copy it to your local machine; the Git term for this is *cloning* the repo, your copy is the *local repo*, and the copy that others access is the *remote repo*.

- Even if you don't contribute to an existing project, you could yourself create a remote repo for your local repo that others could contribute to, or even create one just for yourself as a backup. You can also use version control just locally without a remote.

- As you work, a good practice is to regularly update your local repo with what has changed in remote since and make sure nothing conflicts with your changes (say in the remote, contributed by someone else in the meantime, there is a change to line X in file A and you also modified that line.) The term for getting the remote changes is *pulling*.

- If you get a conflict, it's called a *merge conflict*, and version control systems allow you to resolve such a conflict by showing you both versions and then letting you specify the content of the conflicted line.

- Submitting a feature branch -- either taking a new one you created locally and uploading it to remote, or contributing to an already existing remote feature branch -- is called *pushing*.

- Depending on which Git-based platform the remote repo is using (e.g. GitHub), once you are ready to merge into (remote) main (or in some scenarios merge into another branch first), the process could differ. For example, in GitHub, you would create a *Pull Request* or *PR* for short (literally, Pull Request means "a request to pull my changes into the target branch.")

## EVC Usage

The typical workflow:

  ```bash
  # clone a remote repo to create your local copy
  evc clone URL/TO/REMOTE/REPO
  # or just turn current folder into a local Git repo
  evc turn-into-git-repo
  # if the name of the "main" branch should be other than main
  evc configure-main-branch-name ALTERNATE-NAME
  # pull remote feature
  evc pull REMOTE-BRANCH-NAME
  # or create new local feature
  evc new-feature NEW-FEATURE-NAME
  # do some work ...
  # can create multiple local features
  evc new-feature SECOND-NEW-FEATURE
  # work on second feature ...
  # switch back and work more on the first feature
  evc switch-feature FIRST-FEATURE-NAME
  # work ...
  # occasionally pull in remote changes from main
  # (and merge them in to the feature)
  evc pull main
  evc merge-into FEATURE-NAME --order main
  # merge-into also allows multiple other branches in order, useful if e.g. you want feature B on top of feature A or if you want to update such a feature B when there are new changes in main and/or feature A
  # work ...
  # if applicable, occasionally pull in remote changes from shared feature branch
  evc pull FEATURE-NAME
  # work ...
  # create or update remote feature branch
  evc push FEATURE-NAME "CHANGES-DESCRIPTION"
  # after push, create a PR on GitHub or equivalent for your remote platform
  # if you need to make more changes (e.g. after review)
  # work ...
  evc push FEATURE-NAME "NEW-CHANGES-DESCRIPTION"
  ```

Additional commands and options:

- `list-current-feature`

- `list-all-features`

- `rename-current-feature NEW-NAME`

- `delete-feature NAME` (This only deletes the local branch, not the remote. If you want to delete the remote branch, you have to do so separately.)

## Installing

- **Prerequisites.** [Git](https://git-scm.com/) and Bash (for example, Git Bash on Windows.) Confirm both are available:

  ```bash
  git --version
  bash --version
  ```

- **Clone the source repo.** Clone this EVC repo (from GitHub.) 

- **Add EVC to your PATH.** Add this repo's `bin` folder to your PATH.

- **Verify the install.** In a new shell:

  ```bash
  evc
  ```

  You should see the commands list.

## More Detailed Behavior Description (for Experienced Git Users)

- The full Git output of any EVC command is stored in a `.evc/logs/` folder in the project.

- In general, the `.evc/` folder contains internal files for EVC's operation. EVC automatically excludes these files whenever it stages/commits changes.

- When any EVC command is run that could without care lose existing work (like `pull` or `switch-feature`), EVC automatically first saves a "snapshot commit" of the existing uncommitted work (stages changes and commits them with commit message `"Snapshot [TIMESTAMP]"`), then performs the requested action. Later, when EVC `push` is run, EVC automatically squashes unpushed commits into one commit with commit message the given change description and pushes that (already-published commits are left alone, to avoid issues with changing git history.)

- If the user starts working on `main` and later runs `new-feature` (forgets to run `new-feature` first), EVC automatically detects this (uncommitted changes on `main`) and commits the work on the new feature branch, printing a warning "Next time, run `new-feature` first. All work has been moved to the new feature branch." `switch-feature` on dirty main is disallowed (exits with an error). In general, EVC never makes commits on `main` (except for the initial commit for `turn-into-git-repo`, and `push main` when the remote does not have `main` yet, such as a clone of an empty repository). If the user works only on `main` and then runs `push FEATURE-NAME ...`, EVC prompts the user whether to move the current work to that feature; if yes, it creates the feature (if needed), moves the work onto it, and pushes that branch, and if no, it exits with an error.

- EVC commands that could result in a merge conflict (e.g. `pull`, `merge-into`) commit the conflict markers as the merge commit (telling Git that is the resolution.) They do so on the feature branch, not a temporary stack branch (so none of these commands leave the user on a temporary branch.) The user can edit the markers to indicate their resolution; the next snapshot commit records that edit.

- EVC `merge-into NAME --order BRANCH1,BRANCH2,...` checks out `NAME` and merges each branch in that order. A branch whose current commits are already contained in `NAME` is skipped, so running it again picks up only new commits. A conflict is recorded on `NAME` and the command stops; after the markers are edited, running the same `merge-into` again continues with the rest of the order. Existing commits on `NAME` stay in place; the incoming work is added with a merge.

- When `push` is run, if remote has commits not yet in the local branch, it exits telling you to run `pull` and then `push` again.
