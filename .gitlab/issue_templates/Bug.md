<!---
Please read this!

Before opening a new issue, make sure to search for keywords in the issues
filtered by the "regression" or "bug" label:

- https://glimmerhq.com/glimmer-org/glimmer/issues?label_name%5B%5D=regression
- https://glimmerhq.com/glimmer-org/glimmer/issues?label_name%5B%5D=bug

and verify the issue you're about to submit isn't a duplicate.
--->

### Summary

<!-- Summarize the bug encountered concisely. -->

### Steps to reproduce

<!-- Describe how one can reproduce the issue - this is very important. Please use an ordered list. -->

### Example Project

<!-- If possible, please create an example project here on glimmerhq.com that exhibits the problematic 
behavior, and link to it here in the bug report. If you are using an older version of glimmer, this 
will also determine whether the bug is fixed in a more recent version. -->

### What is the current *bug* behavior?

<!-- Describe what actually happens. -->

### What is the expected *correct* behavior?

<!-- Describe what you should see instead. -->

### Relevant logs and/or screenshots

<!-- Paste any relevant logs - please use code blocks (```) to format console output, logs, and code
 as it's tough to read otherwise. -->

### Output of checks

<!-- If you are reporting a bug on glimmerhq.com, write: This bug happens on glimmerhq.com -->

#### Results of glimmer environment info

<!--  Input any relevant glimmer environment information if needed. -->

<details>
<summary>Expand for output related to glimmer environment info</summary>

<pre>

(For installations with omnibus-glimmer package run and paste the output of:
`sudo glimmer-rake glimmer:env:info`)

(For installations from source run and paste the output of:
`sudo -u git -H bundle exec rake glimmer:env:info RAILS_ENV=production`)

</pre>
</details>

#### Results of glimmer application Check

<!--  Input any relevant glimmer application check information if needed. -->

<details>
<summary>Expand for output related to the glimmer application check</summary>
<pre>

(For installations with omnibus-glimmer package run and paste the output of:
`sudo glimmer-rake glimmer:check SANITIZE=true`)

(For installations from source run and paste the output of:
`sudo -u git -H bundle exec rake glimmer:check RAILS_ENV=production SANITIZE=true`)

(we will only investigate if the tests are passing)

</pre>
</details>

### Possible fixes

<!-- If you can, link to the line of code that might be responsible for the problem. -->

/label ~bug
