param parentName string
@secure()
param uri string

resource appparent 'Microsoft.Web/sites@2021-01-15' existing = {
  name: parentName
}

resource csappdeploy 'Microsoft.Web/sites/extensions@2021-03-01' = {
  name: 'MSDeploy'
  parent: appparent
  properties: {
    packageUri: uri
  }
}
