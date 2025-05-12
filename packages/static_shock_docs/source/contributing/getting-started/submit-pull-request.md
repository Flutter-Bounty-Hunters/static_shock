---
title: Submit a Pull Request (PR)
---
All contributions, such as bug fixes, features, and documentation, are
contributed through pull requests (PRs). Follow standard GitHub processes
to fork Static Shock, make changes, and then submit PRs.

## PR Description Expectations
Your goal when writing a PR description is to make the review process as
easy as humanly possible, for the reviewers. Every bit of difficulty you
add for the reviewer will come back to make things more difficult for you
as a contributor.

Your PR description should provide all relevant context that a reviewer
might want, when reviewing your PR.

Every PR is a bit different, but here are some guiding questions to help
direct your PR description:
 * How did you choose to solve the problem?
 * What other approaches did you consider, and why did you reject them?
 * Did you have to alter or break any pre-existing behavior?
 * Is there a short video you could attach to show what you did?
 * Are there any screenshots you can attach to show what you did?

## Code Expectations
Your code should follow styles and conventions that you find elsewhere in
the codebase. Consistency will be enforced in review.

Your code should include tests that lock down public facing behaviors.
Tests are almost always required for approval.

## Double Check Your Work
Double check your work before submitting it for review.

The following are some guiding questions for your self-review:
 * Did you go to the "Files changed" tab on GitHub and read through your changes?
 * Does every public API in your PR include DartDoc comments?
 * Have you provided inline comments for every confusing snippet of code?
 * If applicable, did you add appropriate website guides?