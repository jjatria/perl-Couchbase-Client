package PLCB_Config;
use strict;
use warnings;
use Dir::Self;
use File::Spec;
use Hash::Util qw(lock_keys);

#this perl 'hash' contains configuration information necessary
#to bootstrap and/or configure the perl couchbase client and run
#necessary tests.

my $params = {
    #URL from which to download the mock JAR file for tests
    COUCHBASE_MOCK_JARURL => 'http://files.couchbase.com/maven2/org/couchbase/mock/CouchbaseMock/0.8-SNAPSHOT/CouchbaseMock-0.8-20140621.030439-1.jar',

    #version numbers for libcouchbase and libvbucket
    LIBCOUCHBASE_RELEASE => '2.3.2',
};


#don't change these, or there may be bad consequences
$params->{SRC_DIR} = File::Spec->catfile(__DIR__, 'src');
$params->{SRC_INST} = File::Spec->catfile($params->{SRC_DIR}, 'inst');

lock_keys(%$params);

return $params; #return value
