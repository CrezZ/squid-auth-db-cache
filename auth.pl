#!/usr/bin/perl
use strict;
use Config::Simple;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use DBI;

sub mysql_connect{
### $dbh=mysql_connect (user, password, host, db)
my $dsn = 'DBI:mysql:database='.$_[3].';host='.$_[2];
#print $dsn;
my $db_user_name = $_[0];
my $db_password  = $_[1];
my ($id, $password);
#print 'pass='.$db_password.';';
my $dbh = DBI->connect($dsn, $db_user_name, $db_password);
return ($dbh);
}

sub oracle_connect{
### use $dbh=oracle_connect (user, password, host);
my $dbh = DBI ->connect
   ( 'dbi:Oracle:host=oracle.net.osu.ru;sid=OSU;port=1521', $_[0], $_[1],
	    {RaiseError => 1,
	     AutoCommit => 0, PrintError=>1} ) or die 'ORACLE cannot connect';;
return ($dbh);
}

sub oracle_query_one{
## use $array=oracle_query_one ($dbh, $user);
    my $oradb=$_[0];
    my $sql = q{
	    BEGIN
	        ASU_WEB.Get_LAN_Pwd_Hash(?,?,?,?);
	    END;
};
    my $sth = $oradb->prepare( $sql );
    $sth->bind_param(1,$_[2]);
    $sth->bind_param_inout(2,\my $result,0);
    $sth->bind_param_inout(3,\my $hash,0);
    $sth->bind_param_inout(4,\my $mess,0);
    $sth->execute();
    my @arr=($result,$hash, $mess);
     return @arr;
}

sub oracle_query_one_test{
    #test for any user with password '123'
    my @arr=(1,md5_hex($_[2].':'.$_[3].':','123'));
    return @arr;
}

sub mysql_query_one{
    my ($mydb,$user,$realm,$ttl)= @_;
    my $sth = $mydb->prepare(qq{select hash, lastdate from users where login=? and TIME_TO_SEC(TIMEDIFF(now(),lastdate))<?  });
    $sth->bind_param(1,$user);
    $sth->bind_param(1,$ttl);
    $sth->execute();
    my ($hash, $date) = $sth->fetchrow_array();
    $sth->finish();
    if ($hash){
	return (1, $hash); 
    } 
    else
    {
	return (0); 
    }
}
sub mysql_query_state{
    my ($mydb)= @_;
    my $sth = $mydb->prepare(qq{select state from state });
    $sth->execute();
    my ($state ) = $sth->fetchrow_array();
    $sth->finish();
	return $state; 
}

sub mysql_cache{
    my ($mydb,$user,$hash,$state)= @_;
    my $sql=qq{insert into users (login,hash,lastdate,state) values (?,?,now(),?)
			    ON DUPLICATE KEY UPDATE hash=?,lastdate=now(),state=?};
    #print $sql;
    my $sth=$mydb->prepare($sql);
    $sth->bind_param(1,$user);
    $sth->bind_param(2,$hash);
    $sth->bind_param(3,$state);
    $sth->bind_param(4,$hash);
    $sth->bind_param(5,$state);
    $sth->execute();
    $sth->finish();

}

sub sigtrap(){
 print "Caught a signal\n";
 exit(1);
}

my $cfg = new Config::Simple('config.conf');
my $oradb=oracle_connect($cfg->param('oracle_login'),$cfg->param('oracle_password'),$cfg->param('oracle_server'));
my $mydb=mysql_connect($cfg->param('mysql_login'),
			$cfg->param('mysql_password').'',
			$cfg->param('mysql_server'),
			$cfg->param('mysql_db'));

$| = 1;
use sigtrap 'handler' => \&sigtrap, 'HUP', 'INT','ABRT','QUIT','TERM';

open(LOG,'>>log-debug.log');

my $time0= time();
# Read from STDIN
my $state=1; #permit all
while (<>) {

my $time = time();

if ($time-$time0>1) # every 1 sec
    {
	$state=mysql_query_state($mydb);
    }

my @input = split /[\"]/;

$input[1] =~ s/^\s+|\s+$//g; #username
$input[3] =~ s/^\s+|\s+$//g; #realm

#print LOG join(",", @input)."\n";

my @hash;
my @cache=mysql_query_one($mydb,$input[1],$input[3], $cfg->param('cache_time'));
if ($cache[0]==1) {
    @hash=(1,$cache[1]);
    #print 'cached';
}
else
{
    @hash=oracle_query_one_test($oradb, $cfg->param('oracle_func'),$input[1],$input[3]);
    if ($hash[0]==1) {mysql_cache($mydb,$input[1],$hash[1],$hash[0]);}
}
#print LOG join(", ", @hash)."\n";
print LOG gmtime().': LOGIN: '.$input[1].': RESULT: '.$hash[0];

if ($hash[0]==1 && $state==1){ # ALL OK
    #print LOG $input[0].'OK ha1="'.$hash[1]."\"\n";
    print  $input[0].'OK ha1="'.$hash[1]."\"\n";
    } else
    {
my $err='';
if ($hash[0]==-3){$err='Invalid login';}
if ($hash[0]==-2){$err='Password not set';}
if ($hash[0]==-1){$err='Login must be lower case';}
if ($hash[0]==0){$err='Invalid password';}
if ($hash[0]==2){$err='Less 18 years';}

print LOG $input[0].' ERR message="'.$err.'"'."\n";
print $input[0].'ERR message="'.$err.'"'."\n";
}

}
close(LOG);
$oradb->disconnect();
$mydb->disconnect();
