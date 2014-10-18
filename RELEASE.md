# How to make a new release of virtualhost.sh

This information is only relevant to [virtualhost.sh maintainers](https://github.com/orgs/virtualhost/people).

In all the examples below 1.32 is used as an example only, change it to the version you are releasing.

1. Increase the version number in virtualhost.sh (the `version` variable).
1. Add to the changelog in virtualhost.sh.
1. (optional) Tag the new release manually with `git tag 1.32` and push the tag with `git push --tags`
1. [Make a new release on GitHub](https://github.com/virtualhost/virtualhost.sh/releases/new) and add the changelog notes there.
1. Submit the new release to Homebrew (below).

## Submit the new release to Homebrew

[Homebrew pull request reference guide](https://github.com/Homebrew/homebrew/wiki/How-To-Open-a-Homebrew-Pull-Request-(and-get-it-merged))

`cd $(brew --repository); brew update`

`git checkout -b virtualhost.sh-1.32`

`brew edit virtualhost.sh` and change the url to **https://github.com/virtualhost/virtualhost.sh/archive/1.32.tar.gz**

`brew reinstall virtualhost.sh` and you will see a message like:

    ==> Reinstalling virtualhost.sh
    ==> Downloading https://github.com/virtualhost/virtualhost.sh/archive/1.32.tar.gz
    ######################################################################## 100.0%
    Error: SHA1 mismatch
    Expected: 25954027dbed14843123bea4efd498cd2abfc4a0
    Actual: dc307937e10c2a5948c59ff2ece6495763415b77
    Archive: /Library/Caches/Homebrew/virtualhost.sh-1.32.tar.gz
    To retry an incomplete download, remove the file above.

Go back to the Homebrew formula and change the sha1 to reflect the 'Actual' sha1. Save your changes.

Run `brew reinstall virtualhost.sh` again, it should work this time.

Push the **virtualhost.sh-1.32** branch to your fork of Homebrew.

Switch back to the master branch on Homebrew: `git checkout master`

Submit a pull request to [Homebrew](https://github.com/Homebrew/homebrew).
