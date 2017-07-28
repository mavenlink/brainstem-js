BrainstemParams = require '../src/brainstem-params'
Utils = require '../src/utils'

describe 'BrainstemParams', ->
  params = null
  beforeEach ->
    params = new BrainstemParams
      collectionName: 'account'
      include: { projects: 'comments' }
      filters:
        project_id: '22'

  it 'is an instance of BrainstemParams', ->
    expect(params instanceof BrainstemParams).toEqual(true)

  it 'should not be a plain old js object', ->
    expect(Utils.isPojo(params)).toEqual(false)

  it 'has accessible params', ->
    expect(params.collectionName).toEqual('account')
    expect(params.include).toEqual({ projects: 'comments' })
    expect(params.filters).toEqual({ project_id: '22' })
