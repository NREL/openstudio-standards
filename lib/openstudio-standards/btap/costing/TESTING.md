# Testing Procedure

To ensure your test and code is functioning properly before it is committed to master, before you do a pull request into master ensure

1. All measures have adequate tests the ensure it's functionality. 
2. Submit a pull request to be reviewed by at least one other member of the team and wait for their review. 
3. Ensure all regression test updates and other text based tests are done on linux or the right line return type is used. 

## Local Testing
Local testing is done using the rake command
```
bundle exec rake test:all_tests
```

This will run all the tests in the test_list.txt file.  If you wish to temporarily remove some test while in development, you may delete any of the test lines. Please ensure that the test list is reset to run all test when you are ready to do a pull request and all tests pass.

