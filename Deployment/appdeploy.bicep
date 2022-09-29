param parentName string
@secure()
param uri string

resource appparent 'Microsoft.Web/sites@2022-03-01' existing = {
  name: parentName
}

resource csappdeploy 'Microsoft.Web/sites/extensions@2022-03-01' = {
  name: 'MSDeploy'
  parent: appparent
  properties: {
    packageUri: uri
  }
}
