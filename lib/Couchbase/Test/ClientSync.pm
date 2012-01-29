package Couchbase::Test::ClientSync;
use strict;
use warnings;
use base qw(Couchbase::Test::Common);
use Test::More;
use Couchbase::Client;
use Couchbase::Client::Errors;
use Data::Dumper;

sub setup_client :Test(startup)
{
    my $self = shift;
    $self->mock_init();
    
    my %options = (
        %{$self->common_options},
        compress_threshold => 100
    );
    
    my $o = Couchbase::Client->new(\%options);
    
    $self->cbo( $o );
    $self->{basic_keys} = [qw(
        Foo Bar Baz Blargh Bleh Meh Grr Gah)];
    $self->err_ok();
}

sub cbo {
    if(@_ == 1) {
        return $_[0]->{object};
    } elsif (@_ == 2) {
        $_[0]->{object} = $_[1];
        return $_[1];
    }
}

sub err_ok {
    my $self = shift;
    my $errors = $self->cbo->get_errors;
    my $nerr = 0;
    foreach my $errinfo (@$errors) {
        $nerr++;
    }
    ok($nerr == 0, "Got no errors");
}

sub k2v {
    my ($self,$k) = @_;
    reverse($k);
}

sub v2k {
    my ($self,$v) = @_;
    reverse($v);
}

sub set_ok {
    my ($self,$msg,@args) = @_;
    my $ret = $self->cbo->set(@args);
    ok($ret->is_ok, $msg);
    $self->err_ok();
    if(!$ret->is_ok) {
        diag($ret->errstr);
    }
}

sub get_ok {
    my ($self,$key,$expected) = @_;
    my $ret = $self->cbo->get($key);
    ok($ret->is_ok, "Status OK for GET($key)");
    ok($ret->value eq $expected, "Got expected value for $key");
}

sub T0_set_values_simple :Test(no_plan) {
    my $self = shift;
    foreach my $k (@{$self->{basic_keys}}) {
        $self->set_ok("Key '$k'", $k, $self->k2v($k));
        $self->get_ok($k, $self->k2v($k))
    }
}

sub T1_get_nonexistent :Test(no_plan) {
    my $self = shift;
    my $v = $self->cbo->get('NonExistent');
    is($v->errnum, COUCHBASE_KEY_ENOENT, "Got ENOENT for nonexistent key");
    $self->err_ok();
}

sub T2_mutators :Test(no_plan) {
    my $self = shift;
    my $o = $self->cbo;
    
    my $key = "mutate_key";
    $o->remove($key); #if it already exists
    is($o->add($key, "BASE")->errnum, 0, "No error for add on new key");
    is($o->prepend($key, "PREFIX_")->errnum, 0, "No error for prepend");
    is($o->append($key, "_SUFFIX")->errnum, 0, "No error for append");
    is($o->get($key)->value, "PREFIX_BASE_SUFFIX", "Got expected mutated value");
}

sub T3_arithmetic :Test(no_plan) {
    my $self = shift;
    my $o = $self->cbo;
    my $key = "ArithmeticKey";
    $o->remove($key);
    my $wv;
    
    $wv = $o->arithmetic($key, -12, 42);
    ok($wv->is_ok, "Set arithmetic with initial value");
    
    $o->remove($key);
    
    $wv = $o->arithmetic($key, -12, undef);   
    is($wv->errnum, COUCHBASE_KEY_ENOENT, "Error without initial value (undef)");
    
    $wv = $o->arithmetic($key, -12, 0, 120);
    ok($wv->is_ok, "No error with initial value=0");
    is($wv->value, 0, "Initial value is 0");
    
    $wv = $o->incr($key);
    is($wv->value, 1, "incr() == 1");
    
    $wv = $o->decr($key);
    is($wv->value, 0, "decr() == 0");
}

sub T4_atomic :Test(no_plan) {
    my $self = shift;
    my $o = $self->cbo;
    my $key = "AtomicKey";
    $o->delete($key);
    
    is($o->replace($key, "blargh")->errnum, COUCHBASE_KEY_ENOENT,
       "Can't replace non-existent value");
    
    my $wv = $o->set($key, "initial");
    ok($wv->errnum == 0, "No error");
    ok(length($wv->cas), "Have cas");
    $o->set($key, "next");
    my $newv = $o->cas($key, "my_next", $wv->cas);
    
    is($newv->errnum,
       COUCHBASE_KEY_EEXISTS, "Got EEXISTS for outdated CAS");
    
    $newv = $o->get($key);
    ok($newv->cas, "Have CAS for new value");
    $wv = $o->cas($key, "synchronized", $newv->cas);
    ok($wv->errnum == 0, "Got no error for CAS with updated CAS");
    is($o->get($key)->value, "synchronized", "Got expected value");
    
    $o->delete($key);
    ok($o->add($key, "value")->is_ok, "No error for ADD with nonexistent key");
    is($o->add($key, "value")->errnum,
       COUCHBASE_KEY_EEXISTS, "Got eexists for ADD on existing key");
    
    ok($o->delete($key, $newv->cas)->errnum, "Got error for DELETE with bad CAS");
    $newv = $o->get($key);
    ok($o->delete($key, $newv->cas)->errnum == 0,
       "No error for delete with updated CAS");
}

sub T5_conversion :Test(no_plan) {
    my $self = shift;
    my $o = $self->cbo;
    my $structure = [ qw(foo bar baz) ];
    my $key = "Serialization";
    my $rv;
    
    ok($o->set($key, $structure)->is_ok, "Serialized OK");
    
    $rv = $o->get($key);
    ok($rv->is_ok, "Got serialized structure OK");
    is_deeply($rv->value, $structure, "Got back our array reference");
    eval {
        $o->append($key, $structure);
    };
    ok($@, "Got error for append/prepending a serialized structure ($@)");
}

1;