path = require 'path'
fs = require 'fs-plus'
temp = require 'temp'
express = require 'express'
http = require 'http'
wrench = require 'wrench'
apm = require '../lib/apm-cli'

describe "apm upgrade", ->
  [atomApp, atomHome, packagesDir, server] = []

  beforeEach ->
    spyOnToken()
    silenceOutput()

    atomHome = temp.mkdirSync('apm-home-dir-')
    process.env.ATOM_HOME = atomHome

    app = express()
    app.get '/packages/test-module', (request, response) ->
      response.sendfile path.join(__dirname, 'fixtures', 'upgrade-test-module.json')
    app.get '/packages/multi-module', (request, response) ->
      response.sendfile path.join(__dirname, 'fixtures', 'upgrade-multi-version.json')
    app.get '/packages/different-repo', (request, response) ->
      response.sendfile path.join(__dirname, 'fixtures', 'upgrade-different-repo.json')
    server =  http.createServer(app)
    server.listen(3000)

    atomHome = temp.mkdirSync('apm-home-dir-')
    atomApp = temp.mkdirSync('apm-app-dir-')
    packagesDir = path.join(atomHome, 'packages')
    process.env.ATOM_HOME = atomHome
    process.env.ATOM_NODE_URL = "http://localhost:3000/node"
    process.env.ATOM_PACKAGES_URL = "http://localhost:3000/packages"
    process.env.ATOM_NODE_VERSION = 'v0.12.0'
    process.env.ATOM_RESOURCE_PATH = atomApp

    fs.writeFileSync(path.join(atomApp, 'package.json'), JSON.stringify(version: '0.12.0'))

  afterEach ->
    server.close()

  it "does not display updates for unpublished packages", ->
    fs.writeFileSync(path.join(packagesDir, 'not-published', 'package.json'), JSON.stringify({name: 'not-published', version: '1.0', repository: 'https://github.com/a/b'}))

    callback = jasmine.createSpy('callback')
    apm.run(['upgrade', '--list', '--no-color'], callback)

    waitsFor 'waiting for upgrade to complete', 600000, ->
      callback.callCount > 0

    runs ->
      expect(console.log).toHaveBeenCalled()
      expect(console.log.argsForCall[1][0]).toContain 'empty'

  it "does not display updates for packages whose engine does not satisfy the installed Atom version", ->
    fs.writeFileSync(path.join(packagesDir, 'test-module', 'package.json'), JSON.stringify({name: 'test-module', version: '0.3.0', repository: 'https://github.com/a/b'}))

    callback = jasmine.createSpy('callback')
    apm.run(['upgrade', '--list', '--no-color'], callback)

    waitsFor 'waiting for upgrade to complete', 600000, ->
      callback.callCount > 0

    runs ->
      expect(console.log).toHaveBeenCalled()
      expect(console.log.argsForCall[1][0]).toContain 'empty'

  it "displays the latest update that satisfies the installed Atom version", ->
    fs.writeFileSync(path.join(packagesDir, 'multi-module', 'package.json'), JSON.stringify({name: 'multi-module', version: '0.1.0', repository: 'https://github.com/a/b'}))

    callback = jasmine.createSpy('callback')
    apm.run(['upgrade', '--list', '--no-color'], callback)

    waitsFor 'waiting for upgrade to complete', 600000, ->
      callback.callCount > 0

    runs ->
      expect(console.log).toHaveBeenCalled()
      expect(console.log.argsForCall[1][0]).toContain 'multi-module 0.1.0 -> 0.3.0'

  it "does not display updates for packages already up to date", ->
    fs.writeFileSync(path.join(packagesDir, 'multi-module', 'package.json'), JSON.stringify({name: 'multi-module', version: '0.3.0', repository: 'https://github.com/a/b'}))

    callback = jasmine.createSpy('callback')
    apm.run(['upgrade', '--list', '--no-color'], callback)

    waitsFor 'waiting for upgrade to complete', 600000, ->
      callback.callCount > 0

    runs ->
      expect(console.log).toHaveBeenCalled()
      expect(console.log.argsForCall[1][0]).toContain 'empty'

  it "does display updates when the installed package's repository is not the same as the available package's repository", ->
    fs.writeFileSync(path.join(packagesDir, 'different-repo', 'package.json'), JSON.stringify({name: 'different-repo', version: '0.3.0', repository: 'https://github.com/world/hello'}))

    callback = jasmine.createSpy('callback')
    apm.run(['upgrade', '--list', '--no-color'], callback)

    waitsFor 'waiting for upgrade to complete', 600000, ->
      callback.callCount > 0

    runs ->
      expect(console.log).toHaveBeenCalled()
      expect(console.log.argsForCall[1][0]).toContain 'different-repo 0.3.0 -> 0.4.0'

  it "allows the package names to upgrade to be specified", ->
    fs.writeFileSync(path.join(packagesDir, 'multi-module', 'package.json'), JSON.stringify({name: 'multi-module', version: '0.1.0', repository: 'https://github.com/a/b'}))
    fs.writeFileSync(path.join(packagesDir, 'different-repo', 'package.json'), JSON.stringify({name: 'different-repo', version: '0.3.0', repository: 'https://github.com/world/hello'}))

    callback = jasmine.createSpy('callback')
    apm.run(['upgrade', '--list', '--no-color', 'different-repo'], callback)

    waitsFor 'waiting for upgrade to complete', 600000, ->
      callback.callCount > 0

    runs ->
      expect(console.log.callCount).toBe 2
      expect(console.log.argsForCall[0][0]).not.toContain 'multi-module 0.1.0 -> 0.3.0'
      expect(console.log.argsForCall[1][0]).toContain 'different-repo 0.3.0 -> 0.4.0'
      expect(console.log.argsForCall[1][0]).not.toContain 'multi-module 0.1.0 -> 0.3.0'

  it "does not display updates when the installed package's repository does not exist", ->
    fs.writeFileSync(path.join(packagesDir, 'different-repo', 'package.json'), JSON.stringify({name: 'different-repo', version: '0.3.0'}))

    callback = jasmine.createSpy('callback')
    apm.run(['upgrade', '--list', '--no-color'], callback)

    waitsFor 'waiting for upgrade to complete', 600000, ->
      callback.callCount > 0

    runs ->
      expect(console.log).toHaveBeenCalled()
      expect(console.log.argsForCall[1][0]).toContain 'empty'

  it "logs an error when the installed location of Atom cannot be found", ->
    process.env.ATOM_RESOURCE_PATH = '/tmp/atom/is/not/installed/here'
    callback = jasmine.createSpy('callback')
    apm.run(['upgrade', '--list', '--no-color'], callback)

    waitsFor 'waiting for upgrade to complete', 600000, ->
      callback.callCount > 0

    runs ->
      expect(console.error).toHaveBeenCalled()
      expect(console.error.argsForCall[0][0]).toContain 'Could not determine current Atom version installed'

  it "ignores the commit SHA suffix in the version", ->
    fs.writeFileSync(path.join(atomApp, 'package.json'), JSON.stringify(version: '0.10.0-deadbeef'))
    fs.writeFileSync(path.join(packagesDir, 'multi-module', 'package.json'), JSON.stringify({name: 'multi-module', version: '0.1.0', repository: 'https://github.com/a/b'}))

    callback = jasmine.createSpy('callback')
    apm.run(['upgrade', '--list', '--no-color'], callback)

    waitsFor 'waiting for upgrade to complete', 600000, ->
      callback.callCount > 0

    runs ->
      expect(console.log).toHaveBeenCalled()
      expect(console.log.argsForCall[1][0]).toContain 'multi-module 0.1.0 -> 0.3.0'
