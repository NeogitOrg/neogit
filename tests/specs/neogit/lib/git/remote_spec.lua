local git = require("neogit.lib.git")

describe("lib.git.remote", function()
  describe("#parse", function()
    it("can parse 'git@github.com:owner/repo.git'", function()
      local url = "git@github.com:owner/repo.git"

      assert.are.same(git.remote.parse(url), {
        host = "github.com",
        owner = "owner",
        path = "owner",
        protocol = "ssh",
        repo = "repo",
        repository = "repo",
        url = "ssh://git@github.com/owner/repo.git",
        user = "git",
      })
    end)

    it("can parse 'https://github.com/owner/repo.git'", function()
      local url = "https://github.com/owner/repo.git"

      assert.are.same(git.remote.parse(url), {
        host = "github.com",
        owner = "owner",
        path = "owner",
        protocol = "https",
        repo = "repo",
        repository = "repo",
        url = "https://github.com/owner/repo.git",
      })
    end)

    it("can parse 'git@gitlab.com:owner/repo.git'", function()
      local url = "git@gitlab.com:owner/repo.git"

      assert.are.same(git.remote.parse(url), {
        host = "gitlab.com",
        owner = "owner",
        path = "owner",
        protocol = "ssh",
        repo = "repo",
        repository = "repo",
        url = "ssh://git@gitlab.com/owner/repo.git",
        user = "git",
      })
    end)

    it("can parse 'https://gitlab.com/owner/repo.git'", function()
      local url = "https://gitlab.com/owner/repo.git"

      assert.are.same(git.remote.parse(url), {
        host = "gitlab.com",
        owner = "owner",
        path = "owner",
        protocol = "https",
        repo = "repo",
        repository = "repo",
        url = "https://gitlab.com/owner/repo.git",
      })
    end)

    it("can parse 'ssh://git@gitlab.priv/project/path/repo.git'", function()
      local url = "ssh://git@gitlab.priv/project/path/repo.git"

      assert.are.same(git.remote.parse(url), {
        host = "gitlab.priv",
        owner = "project/path",
        path = "project/path",
        protocol = "ssh",
        repo = "repo",
        repository = "repo",
        url = "ssh://git@gitlab.priv/project/path/repo.git",
        user = "git",
      })
    end)

    it("can parse 'git@gitlab.private-with-dash:project/path/repo.git'", function()
      local url = "git@gitlab.private-with-dash:project/path/repo.git"

      assert.are.same(git.remote.parse(url), {
        host = "gitlab.private-with-dash",
        owner = "project/path",
        path = "project/path",
        protocol = "ssh",
        repo = "repo",
        repository = "repo",
        url = "ssh://git@gitlab.private-with-dash/project/path/repo.git",
        user = "git",
      })
    end)

    it("can parse 'ssh://git@gitlab.priv:2222/project/path/repo.git'", function()
      local url = "ssh://git@gitlab.priv:2222/project/path/repo.git"

      assert.are.same(git.remote.parse(url), {
        host = "gitlab.priv",
        owner = "project/path",
        path = "project/path",
        port = "2222",
        protocol = "ssh",
        repo = "repo",
        repository = "repo",
        url = "ssh://git@gitlab.priv:2222/project/path/repo.git",
        user = "git",
      })
    end)

    it("can parse 'ssh://git:pass@gitlab.priv:2222/project/path/repo.git'", function()
      local url = "ssh://git:pass@gitlab.priv:2222/project/path/repo.git"

      assert.are.same(git.remote.parse(url), {
        host = "gitlab.priv",
        owner = "project/path",
        path = "project/path",
        port = "2222",
        protocol = "ssh",
        repo = "repo",
        repository = "repo",
        url = "ssh://git:pass@gitlab.priv:2222/project/path/repo.git",
        user = "git",
      })
    end)

    it("can parse 'https://gitlab.priv/project/path/repo.git'", function()
      local url = "https://gitlab.priv/project/path/repo.git"

      assert.are.same(git.remote.parse(url), {
        host = "gitlab.priv",
        owner = "project/path",
        path = "project/path",
        protocol = "https",
        repo = "repo",
        repository = "repo",
        url = "https://gitlab.priv/project/path/repo.git",
      })
    end)

    it("can parse 'https://gitlab.priv:4443/project/path/repo.git'", function()
      local url = "https://gitlab.priv:4443/project/path/repo.git"

      assert.are.same(git.remote.parse(url), {
        host = "gitlab.priv",
        owner = "project/path",
        path = "project/path",
        port = "4443",
        protocol = "https",
        repo = "repo",
        repository = "repo",
        url = "https://gitlab.priv:4443/project/path/repo.git",
      })
    end)

    it("can parse 'git@github.com:owner-with-dashes/repo.git'", function()
      local url = "git@github.com:owner-with-dashes/repo.git"

      assert.are.same(git.remote.parse(url), {
        host = "github.com",
        owner = "owner-with-dashes",
        path = "owner-with-dashes",
        protocol = "ssh",
        repo = "repo",
        repository = "repo",
        url = "ssh://git@github.com/owner-with-dashes/repo.git",
        user = "git",
      })
    end)

    it("can parse 'git@github.com:owner/repo-with_specials.git'", function()
      local url = "git@github.com:owner/repo-with_specials.git"

      assert.are.same(git.remote.parse(url), {
        host = "github.com",
        owner = "owner",
        path = "owner",
        protocol = "ssh",
        repo = "repo-with_specials",
        repository = "repo-with_specials",
        url = "ssh://git@github.com/owner/repo-with_specials.git",
        user = "git",
      })
    end)

    it("can parse 'git://git@github.com/owner/repo-with_specials.git'", function()
      local url = "git://git@github.com/owner/repo-with_specials.git"

      assert.are.same(git.remote.parse(url), {
        host = "github.com",
        owner = "owner",
        path = "owner",
        protocol = "git",
        repo = "repo-with_specials",
        repository = "repo-with_specials",
        url = "git://git@github.com/owner/repo-with_specials.git",
        user = "git",
      })
    end)

    it("can parse 'https://github.com/my-org/myrepo' - no .git suffix", function()
      local url = "https://github.com/my-org/myrepo"

      assert.are.same(git.remote.parse(url), {
        host = "github.com",
        owner = "my-org",
        protocol = "https",
        repo = "myrepo",
        repository = "myrepo",
        path = "my-org",
        url = "https://github.com/my-org/myrepo",
      })
    end)
  end)
end)
