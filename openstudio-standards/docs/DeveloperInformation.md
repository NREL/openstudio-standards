# Developer Information

## Setup

1. Install the {https://www.openstudio.net/downloads latest version of OpenStudio}
2. **On Windows**, install {http://rubyinstaller.org/ Ruby 2.0} (`ruby -v` from command prompt to check installed version).  
3. **On Mac** Ruby 2.0 is already installed.
4. Connect Ruby to OpenStudio:
	1. **On Mac**:
	2. Create a file called `openstudio.rb`
	3. Contents: `require "/Applications/OpenStudio\ 1.9.0/Ruby/openstudio.rb"` Modify `1.9.0` to the version you installed.
	4. Save it here: `/usr/lib/ruby/site_ruby/openstudio.rb`
	5. **On Windows**:
	6. Create a file called `openstudio.rb`
	7. Contents: `require "C:/Program Files/OpenStudio 1.9.3/Ruby/openstudio.rb"`  Modify `1.9.0` to the version you installed.
	8. Save it here: `C:/MyRuby200/lib/ruby/site_ruby/openstudio.rb`

5. Install the `bundler` ruby gem. (`gem install bundler` from command prompt)
6. Install the `json` ruby gem. (`gem install json` from command prompt)
7. Install {https://git-scm.com/ Git}.
8. Clone the {https://github.com/NREL/openstudio-standards.git source code} using {https://git-scm.com/ Git}.
9. Run all commands below from the `/openstudio-standards/openstudio-standards` directory 
10. **On Windows**, use the Git Bash instead of the default command prompt.
11. **On Mac** the default terminal is fine.
11. Navigate to the `openstudio-standards/openstudio-standards` directory.
12. Command prompt: `bundle install`. This will install all ruby gems necessary to develop this code.
13. Sign up for an account at {https://circleci.com/ CircleCI} and follow the `NREL/openstudio-standards` project.
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
2. `ruby test/test_XX.rb` Run your new test file.
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
2. Merge /Master into your branch and resolve any conflicts.
2. Push your branch to GitHub.
3. DO NOT push your code to the /Master branch!

### Pull request

Once your code is done and the tests are passing locally on your branch with Master merged in, go to GitHub and create a Pull Request.  This tells the main developers that you have changes to bring into the main code.

### Code Review & Merge

The main developers will review your changes and either approve the pull request or give you some comments.  If they approve the pull request, you are done and your changes are now part of the main code!

### Look at the continuous integration results

1. When a commit is made to /Master, the continuous integration machine will run all the tests.
2. Go to {https://circleci.com/gh/NREL/openstudio-standards openstudio-standards Circle CI} and look at the NREL/openstudio-standards project to check out the build status.  If it is failing and your commit broke it, please fix it ASAP!  Also, you can follow a project on Circle CI and you will get email updates when someone breaks the build.

## Issues and New Features

1. Issues and feature requests are reported on the {https://github.com/NREL/openstudio-standards/issues GitHub Repository Issues Page}.
2. Issues should be labeled according to the {https://github.com/NREL/OpenStudio/wiki/Issue-Prioritization OpenStudio Issue Prioritization Guide}
3. Failing tests do not need to be listed as issues; they should be fixed if they fail.