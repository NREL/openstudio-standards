# Developer Information

## Setup

1. On Windows, install {http://rubyinstaller.org/ Ruby 2.0} (`ruby -v` from command prompt to check installed version).
2. Install the `bundler` ruby gem. (`gem install bundler` from command prompt)
3. Install {https://git-scm.com/ Git}.
4. Clone the {https://github.com/NREL/openstudio-standards.git source code} using {https://git-scm.com/ Git}.
5. Run all commands below from the `/openstudio-standards/openstudio-standards` directory 
6. On Windows, use the Git Bash instead of the default command prompt.
7. Navigate to the `openstudio-standards/openstudio-standards` directory.
8. Command prompt: `bundle install`. This will install all ruby gems necessary to develop this code.
9. Sign up for an account at {https://circleci.com/ CircleCI} and follow the `NREL/openstudio-standards` project.
10. That's it, you are ready to make changes!

## Development Process

### Summary

1. Modify the code
2. Test the code (new code plus old code to make sure you didn't break anything)
3. Document the code
5. Push branch to GitHub repository
6. Continuous automation runs tests
7. Pull request
8. Code review and merge 

This project uses {http://rake.rubyforge.org/ Rake} to run tasks from the terminal.  

`rake -T`: List all available commands

- `rake btest`: builds the gem, installs it, and runs the tests
- `rake build`: builds the gem
- `rake data:update`: downloads and exports OpenStudio_Standards Google Spreadsheet
- `rake doc`: generates the documentation
- `rake doc:show`: generates and shows the documentation
- `rake install`: installs the gem
- `rake install:local`: installs the gem locally
- `rake release`: pushes the code to RubyGems.org
- `rake rubocop`: checks the code syntax
- `rake rubocop:auto_correct`: fixes mistakes in code syntax
- `rake test:all`: runs the gem tests & measure tests
- `rake test:gem`: runs the gem tests
- `rake test:measures`: runs the measures tests
 
### Modify the code

As you add to/modify the code, please try to fit changes into the current structure rather than bolting things on willy-nilly.  See the {file:openstudio-standards/docs/CodeStructure.md Code Structure page} to see how the code is organized.  If you don't understand something or want to discuss your plan before you get started, contact {mailto:andrew.parker@nrel.gov}.

1. Make a new branch for your changes.
2. Modify the code on your branch.
3. Modify the {https://docs.google.com/spreadsheets/d/15-mlZrWbA4srtFHtWRP1dgPeuI5plFdjCb1B79fEukI/edit?usp=sharing OpenStudio_Standards Google Spreadsheet}
4. `rake data:update` to download the latest version of the spreadsheet from Google Drive and export the JSON files.

### Test the code

Tests prove that your code works as expected, but more importantly they help make sure that changes don't break other code.  If your code doesn't have tests and someone else makes changes that break it, it's your own fault.

1. Create a new file called `test_XX.rb` in the `/test` directory.
2. Put tests into your file.  See other test files for examples.
2. `rake test TEST=path_to_test_XX.rb` Run your new test file.
3. Fix your code and make sure your tests pass.
4. `rake test:all` Run all the tests to make sure you didn't break existing code.
5. Fix your code and make sure all tests pass.

### Document the code

Good documentation is critical.  Changes or additions without good documentation will not be accepted.  This library uses {http://yardoc.org/ YARD} to generate documentation.  You simply write the documentation inline as specially tagged comments and the rest happens automagically.  This {https://gist.github.com/chetan/1827484#methods YARD cheat sheet} quickly shows you how to document things.  You can also look at the other methods documented in the code.

1. Make sure your methods are documented.
2. `rake doc` Generate the documentation and document any undocumented methods that are listed
3. `rake doc:show` Inspect the documentation in a browser to make sure it looks right.
   
### Push branch to GitHub

1. Commit your changes to your branch.
2. Push your branch to GitHub.
3. DO NOT push your code to the /Master branch!

### Look at the continuous integration results

1. Go to {https://circleci.com/gh/NREL/openstudio-standards openstudio-standards Circle CI}
2. Check out the build status.  If it is failing, 

### Pull request

Once your code is done and all of the tests are passing, go to GitHub and create a Pull Request.  This tells the main developers that you have changes to bring into the main code.

### Code Review & Merge

The main developers will review your changes and either approve the pull request or give you some comments.  If they approve the pull request, you are done and your changes are now part of the main code!

## Issues and New Features

1. Issues and feature requests are reported on the {https://github.com/NREL/openstudio-standards/issues GitHub Repository Issues Page}.
2. Issues should be labeled according to the {https://github.com/NREL/OpenStudio/wiki/Issue-Prioritization OpenStudio Issue Prioritization Guide}
3. Failing tests do not need to be listed as issues; they should be fixed if they fail.