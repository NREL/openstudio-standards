//Jenkins pipelines are stored in shared libaries. Please see: https://github.com/tijcolem/nrel_cbci_jenkins_libs

@Library('cbci_shared_libs@master') _

// Build for PR to master branch only.
if ((env.CHANGE_ID) && (env.CHANGE_TARGET) ) { // check if set

  openstudio_standards()

}
