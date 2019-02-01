Pod::Spec.new do |s|
  s.name = 'TMGHTTPClockSync'
  s.version = '1.0.0'
  s.license = 'BSD'
  s.summary = 'Sync device and server clocks over HTTP'
  s.homepage = 'https://github.com/MeetMe/TMGHTTPClockSync'
  s.authors = { 'The Meet Group' => '' }
  s.source = { :git => 'https://github.com/MeetMe/TMGHTTPClockSync.git', :tag => s.version }

  s.ios.deployment_target = '9.0'

  s.source_files = 'TMGHTTPClockSyncTests/*.swift'
end
