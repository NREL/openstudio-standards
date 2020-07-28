# Developer Information

## Setup

1. Install the [latest version of OpenStudio](https://www.openstudio.net/downloads). Minimum supported version is 3.0.0.
2. Install Ruby:
      1. **On Mac**:
      2. Install Ruby 2.5.X using [rbenv](http://octopress.org/docs/setup/rbenv/) (`ruby -v` from command prompt to check installed version).
      3. **On Windows**:
      4. Install [Ruby+Devkit 2.5.8](https://rubyinstaller.org/downloads/) (`ruby -v` from command prompt to check installed version).
      5. **Using BTAP development Environment**
      6. Do nothing.

4. Connect Ruby to OpenStudio:
	1. **On Mac**:
	2. Create a file called `openstudio.rb`
	3. Contents: `require "/Applications/openstudio-3.0.0/Ruby/openstudio.rb"`. Modify `3.0.0` to the version you installed.
	4. Save it here: `/usr/lib/ruby/site_ruby/openstudio.rb`
	5. **On Windows**:
	6. Create a file called `openstudio.rb`
	7. Contents: `require "C:/openstudio-3.0.0/Ruby/openstudio.rb"`.  Modify `3.0.0` to the version you installed.
	8. Save it here: `C:/Ruby25-x64/lib/ruby/site_ruby/openstudio.rb`
	9. Start > right click Computer > Properties > Advanced system settings > Environment variables.  In the User variables section (top) add a new Variable with the name `GEM_PATH` and the Value `C:\Ruby25-x64\lib\ruby\gems\2.5.0`.
	10. **Using BTAP development Environment**
	11.  Do nothing.

5. Install the `bundler` ruby gem. (`gem install bundler` from command prompt)
6. Install [Git](https://git-scm.com/).
7. Install [GitHub desktop](https://desktop.github.com/) or another GUI that makes Git easier to use.
8. Clone the [source code](https://github.com/NREL/openstudio-standards.git) using GitHub desktop (easier) or Git (harder).
9. Run all commands below from the top level directory 
10. **On Windows**, use the Git Bash instead of the default command prompt.
11. **On Mac** the default terminal is fine.
12. **Using BTAP development Environment** use the terminator terminal ideally.
13. Command prompt: `bundle install`. This will install all ruby gems necessary to develop this code.
14. That's it, you are ready to make changes!

## Development Process

### Summary

1. Modify the code
2. Test the code (new code plus old code to make sure you didn't break anything)
3. Document the code
5. Push branch to GitHub repository
6. Continuous automation runs tests
7. Pull request
8. Code review and merge 

This project uses [Rake](http://rake.rubyforge.org/) to run tasks from the terminal.  

`bundle exec rake -T`: List all available commands

- `bundle exec rake build`                    # Build openstudio-standards-X.X.XX.gem into the pkg directory
- `bundle exec rake clean`                    # Remove any temporary products
- `bundle exec rake clobber`                  # Remove any generated files
- `bundle exec rake data:update`              # Download OpenStudio_Standards from Google & export JSONs
- `bundle exec rake data:update:costing`      # Update RS-Means Database
- `bundle exec rake data:update:manual`       # Export JSONs from OpenStudio_Standards
- `bundle exec rake doc`                      # Generate the documentation
- `bundle exec rake doc:show`                 # Show the documentation in a web browser
- `bundle exec rake install`                  # Build and install openstudio-standards-X.X.XX.gem into system gems
- `bundle exec rake install:local`            # Build and install openstudio-standards-X.X.XX.gem into system gems without network access
- `bundle exec rake library:export`           # Export libraries for the OpenStudio Application
- `bundle exec rake release[remote`]          # Create tag vX.X.XX and build and push openstudio-standards-X.X.XX.gem to Rubygems
- `bundle exec rake rubocop`                  # Check the code for style consistency
- `bundle exec rake rubocop:auto_correct`     # Auto-correct RuboCop offenses
- `bundle exec rake rubocop:show`             # Show the rubocop output in a web browser
- `bundle exec rake test:btap_json_test`      # Run tests for btap_json_test
- `bundle exec rake test:circ-90_1_general`   # Run tests for circ-90_1_general
- `bundle exec rake test:circ-90_1_prm`       # Run tests for circ-90_1_prm
- `bundle exec rake test:circ-all-tests`      # Run tests for circ-all-tests
- `bundle exec rake test:circ-doe_prototype`  # Run tests for circ-doe_prototype
- `bundle exec rake test:circ-necb`           # Run tests for circ-necb
- `bundle exec rake test:circ-necb_bldg`      # Run tests for circ-necb_bldg
- `bundle exec rake test:necb_local_bldgs_regression_tests`  # Run tests for necb_local_bld...`
 
### Modify the code

As you add to/modify the code, please try to fit changes into the current structure rather than bolting things on willy-nilly.  See the {file:docs/RepositoryStructure.md Repository Structure page} to see how the code is organized.  If you don't understand something or want to discuss your plan before you get started, contact <mailto:andrew.parker@nrel.gov>.

1. Make a new branch for your changes.
2. Modify the code on your branch.
3. Modify the [OpenStudio_Standards Google Spreadsheet](https://drive.google.com/drive/folders/1x7yEU4jnKw-gskLBih8IopStwl0KAMEi?usp=sharing)
 - To get edit access to this spreadsheet, contact <mailto:Marlena.Praprost@nrel.gov>.
4. `bundle exec rake data:update` to download the latest version of the spreadsheet from Google Drive and export the JSON files.

### Test the code

Tests prove that your code works as expected, but more importantly they help make sure that changes don't break other code.  If your code doesn't have tests and someone else makes changes that break it, it's your own fault.

1. Create a new file called `test_XX.rb` in the `/test/subdirectory` directory.
2. Put tests into your file.  See other test files for examples.
2. `ruby test/subdirectory/test_XX.rb` Run your new test file.
3. Fix your code and make sure your tests pass.

### Document the code

Good documentation is critical.  Changes or additions without good documentation will not be accepted.  This library uses [YARD](http://yardoc.org/) to generate documentation.  You simply write the documentation inline as specially tagged comments and the rest happens automagically.  This [YARD cheat sheet](https://gist.github.com/chetan/1827484#methods) quickly shows you how to document things.  You can also look at the other methods documented in the code.

1. Make sure your methods are documented.
2. `bundle exec rake doc` Generate the documentation and document any undocumented methods that are listed
3. `bundle exec rake doc:show` Inspect the documentation in a browser to make sure it looks right.
   
### Push branch to GitHub

1. Commit your changes to your branch.
2. Merge /Master into your branch and resolve any conflicts.
2. Push your branch to GitHub.
3. DO NOT push your code to the /Master branch!

### Pull request

Once your code is done and the tests are passing locally on your branch with Master merged in, go to GitHub and create a Pull Request.  This tells the main developers that you have changes to bring into the main code.

### Code Review & Merge

The main developers will review your changes and either approve the pull request or give you some comments.  If they approve the pull request, you are done and your changes are now part of the main code!

### Look at the continuous integration results

1. When a commit is made to any branch, the continuous integration machine will run all the tests.
2. For pull requests, the status of the tests will automatically be posted to GitHub.
3. Developers will need to be given access to the continuous integration system to see detailed results.

## Issues and New Features

1. Issues and feature requests are reported on the [GitHub Repository Issues Page](https://github.com/NREL/openstudio-standards/issues ).
2. Issues should be labeled according to the [OpenStudio Issue Prioritization Guide](https://github.com/NREL/OpenStudio/wiki/Issue-Prioritization)
3. Failing tests do not need to be listed as issues; they should be fixed if they fail.
