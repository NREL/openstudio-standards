Pull request overview
---------------------

<!--- DESCRIBE PURPOSE OF THIS PULL REQUEST -->

 - Fixes #ISSUENUMBERHERE (IF THIS IS A DEFECT)

### Pull Request Author

<!--- Add to this list or remove from it as applicable.  This is a simple templated set of guidelines. -->

 - [ ] Method changes or additions
 - [ ] Data changes or additions
 - [ ] Added tests for added methods
 - [ ] If methods have been deprecated, update rest of code to use the new methods
 - [ ] Documented new methods using [yard syntax](https://rubydoc.info/gems/yard/file/docs/GettingStarted.md)
 - [ ] Resolved yard documentation errors for new code (ran `bundle exec rake doc`)
 - [ ] Resolved rubocop syntax errors for new code (ran `bundle exec rake rubocop`)
 - [ ] All new and existing tests passes
 - [ ] If the code adds new `require` statements, ensure these are in core ruby or add to the gemspec

### Review Checklist

This will not be exhaustively relevant to every PR.
 - [ ] Perform a code review on GitHub
 - [ ] All related changes have been implemented: method additions, changes, tests
 - [ ] Check rubocop errors
 - [ ] Check yard doc errors
 - [ ] If fixing a defect, verify by running develop branch and reproducing defect, then running PR and reproducing fix
 - [ ] If a new feature, test the new feature and try creative ways to break it
 - [ ] CI status: all green or justified
