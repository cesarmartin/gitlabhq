# GitLab Developers Guide to Working with Gitaly

[Gitaly](https://gitlab.com/gitlab-org/gitaly) is a high-level Git RPC service used by GitLab CE/EE,
Workhorse and GitLab-Shell.

## Developing new Git features

Starting with GitLab 10.8, all new Git features should be developed in
Gitaly.

> This is a new process that is not clearly defined yet. If you want
to contribute a Git feature and you're getting stuck, reach out to the
Gitaly team or `@jacobvosmaer-gitlab`.

By 'new feature' we mean any method or class in `lib/gitlab/git` that is
called from outside `lib/gitlab/git`. For new methods that are called
from inside `lib/gitlab/git`, see 'Modifying existing Git features'
below.

There should be no new code that touches Git repositories via
disk access (e.g. Rugged, `git`, `rm -rf`) anywhere outside
`lib/gitlab/git`.

The process for adding new Gitaly features is:

- exploration / prototyping
- design and create a new Gitaly RPC [in gitaly-proto](https://gitlab.com/gitlab-org/gitaly-proto)
- release a new version of gitaly-proto
- write implementation and tests for the RPC [in Gitaly](https://gitlab.com/gitlab-org/gitaly), in Go or Ruby
- release a new version of Gitaly
- write client code in gitlab-ce/ee, gitlab-workhorse or gitlab-shell that calls the new Gitaly RPC

These steps often overlap. It is possible to use an unreleased version
of Gitaly and gitaly-proto during testing and development.

- See the [Gitaly repo](https://gitlab.com/gitlab-org/gitaly/blob/master/CONTRIBUTING.md#development-and-testing-with-a-custom-gitaly-proto) for instructions on writing server side code with an unreleased protocol.
- See [below](#running-tests-with-a-locally-modified-version-of-gitaly) for instructions on running gitlab-ce tests with a modified version of Gitaly.
- In GDK run `gdk install` and restart `gdk run` (or `gdk run app`) to use a locally modified Gitaly version for development

### Gitaly-ruby

It is possible to implement and test RPC's in Gitaly using Ruby code,
in
[gitaly-ruby](https://gitlab.com/gitlab-org/gitaly/tree/master/ruby).
This should make it easier to contribute for developers who are less
comfortable writing Go code.

There is documentation for this approach in [the Gitaly
repo](https://gitlab.com/gitlab-org/gitaly/blob/master/doc/ruby_endpoint.md).

## Gitaly-Related Test Failures

If your test-suite is failing with Gitaly issues, as a first step, try running:

```shell
rm -rf tmp/tests/gitaly
```

## `TooManyInvocationsError` errors

During development and testing, you may experience `Gitlab::GitalyClient::TooManyInvocationsError` failures.
The `GitalyClient` will attempt to block against potential n+1 issues by raising this error
when Gitaly is called more than 30 times in a single Rails request or Sidekiq execution.

As a temporary measure, export `GITALY_DISABLE_REQUEST_LIMITS=1` to suppress the error. This will disable the n+1 detection
in your development environment.

Please raise an issue in the GitLab CE or EE repositories to report the issue. Include the labels ~Gitaly
~performance ~"technical debt". Please ensure that the issue contains the full stack trace and error message of the
`TooManyInvocationsError`. Also include any known failing tests if possible.

Isolate the source of the n+1 problem. This will normally be a loop that results in Gitaly being called for each
element in an array. If you are unable to isolate the problem, please contact a member
of the [Gitaly Team](https://gitlab.com/groups/gl-gitaly/group_members) for assistance.

Once the source has been found, wrap it in an `allow_n_plus_1_calls` block, as follows:

```ruby
# n+1: link to n+1 issue
Gitlab::GitalyClient.allow_n_plus_1_calls do
  # original code
  commits.each { |commit| ... }
end
```

Once the code is wrapped in this block, this code-path will be excluded from n+1 detection.

## Request counts

Commits and other git data, is now fetched through Gitaly. These fetches can,
much like with a database, be batched. This improves performance for the client
and for Gitaly itself and therefore for the users too. To keep performance stable
and guard performance regressions, Gitaly calls can be counted and the call count
can be tested against. This requires the `:request_store` flag to be set.

```ruby
describe 'Gitaly Request count tests' do
  context 'when the request store is activated', :request_store do
    it 'correctly counts the gitaly requests made' do
      expect { subject }.to change { Gitlab::GitalyClient.get_request_count }.by(10)
    end
  end
end
```

## Running tests with a locally modified version of Gitaly

Normally, gitlab-ce/ee tests use a local clone of Gitaly in
`tmp/tests/gitaly` pinned at the version specified in
`GITALY_SERVER_VERSION`. The `GITALY_SERVER_VERSION` file supports
`=my-branch` syntax to use a custom branch in gitlab-org/gitaly. If
you want to run tests locally against a modified version of Gitaly you
can replace `tmp/tests/gitaly` with a symlink. This is much faster
because the `=my-branch` syntax forces a Gitaly re-install each time
you run `rspec`.

```shell
rm -rf tmp/tests/gitaly
ln -s /path/to/gitaly tmp/tests/gitaly
```

Make sure you run `make` in your local Gitaly directory before running
tests. Otherwise, Gitaly will fail to boot.

If you make changes to your local Gitaly in between test runs you need
to manually run `make` again.

Note that CI tests will not use your locally modified version of
Gitaly. To use a custom Gitaly version in CI you need to update
GITALY_SERVER_VERSION. You can use the format `=revision` to use a
non-tagged commit from https://gitlab.com/gitlab-org/gitaly in CI.

---

[Return to Development documentation](README.md)
