#!/usr/bin/perl
use strict;
use Config::Simple;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use DBI;

my $DEBUG=1;

sub mysql_connect{
    my ($db_user_name, $db_password, $host, $db) = @_;
    ### $dbh=mysql_connect (user, password, host, db)
    my $dsn = 'DBI:mysql:database='.$db.';host='.$host;
    my $dbh = DBI->connect($dsn, $db_user_name, $db_password);
    return ($dbh);
}

sub oracle_connect{
### use $dbh=oracle_connect (user, password, host);
    my ($login,$pass,$host) = @_;
  my $dbh = DBI ->connect
   ( 'dbi:Oracle:host='.$host.';sid=OSU;port=1521', $login, $pass,
	    {RaiseError => 1,
	     AutoCommit => 0, PrintError=>1} ) or die 'ORACLE cannot connect';;
return ($dbh);
}

sub oracle_query_one{
    my ($oradb,$func,$login,$realm)=@_;
## use $array=oracle_query_one ($dbh, $func, $user, $realm);
    my $sql = qq{
	    BEGIN
	        $func(?,?,?,?);
	    END;
};
    my $sth = $oradb->prepare( $sql );
    $sth->bind_param(1,$login);
    $sth->bind_param_inout(2,\my $result,1);
    $sth->bind_param_inout(3,\my $hash,33);
    $sth->bind_param_inout(4,\my $mess,100);
    $sth->execute();
    my @arr=($result,$hash, $mess);
     return @arr;
}

sub oracle_query_one_test{
    my ($oradb,$func,$login,$realm)=@_;
    #test for any user with password '123'
    my @arr=(1,md5_hex($login.':'.$realm.':'.'123'));
    return @arr;
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


sub mysql_query_one{
    my ($mydb,$user,$realm,$ttl,$ttl2,$DEBUG)= @_;
        if ($DEBUG){open(F,"|/usr/bin/logger Search mysql..");close(F);}
    my $sth = $mydb->prepare(qq{select hash, to_seconds(lastdate), users.state, state.state, to_seconds(now())
			    from users 
			    join state on (state.id=1)
			    where login=?  });
    $sth->bind_param(1,$user);
    $sth->execute();
    my ($hash, $date, $state, $globalstate, $now) = $sth->fetchrow_array();
    $sth->finish();

    if ($state != 0 && $globalstate==0) { #force deauth user
        my $sth2 = $mydb->prepare("UPDATE users set state=0,lastdate=now() where login=? limit 1");
        $sth2->bind_param(1,$user);
        $sth2->execute();
        $sth2->finish();
        if ($DEBUG){open(F,"|/usr/bin/logger Made deauth");close(F);}
	return (0,'');
    }
    if ($state == 0 && $globalstate==0 && $now-$date>$ttl2) { #restore deauth user for $ttl2 time
        if ($DEBUG){open(F,"|/usr/bin/logger Expire TTL2");close(F);}
        my $sth2 = $mydb->prepare("UPDATE users set state=1,lastdate=now() where login=? limit 1"); #TODO - use laststate
        $sth2->bind_param(1,$user);
        $sth2->execute();
        $sth2->finish();
        if ($DEBUG){open(F,"|/usr/bin/logger Made deauth");close(F);}
	return (0,'');
    }
    if ($state == 0 && $globalstate==0 && $now-$date<$ttl2) { #restore deauth user for $ttl2 time
        if ($DEBUG){open(F,"|/usr/bin/logger wait TTL2");close(F);}
	return (1,$hash);
    }
    if ($now-$date > $ttl) { #// Expire cache
	if ($DEBUG){open(F,"|/usr/bin/logger Expire TTL");close(F);}
	return (20,'');
    } 
    if ($hash){
        if ($DEBUG){open(F,"|/usr/bin/logger Valid hash");close(F);}
	return ($state, $hash); 
    }else
    { 
	if ($DEBUG){open(F,"|/usr/bin/logger Invalid hash");close(F);}
        return (20,''); ##any more - go to oracle
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


sub sigtrap(){ # KILL handler
 print "Caught a signal\n";
 exit(1);
}


#########################################################################################################
#########################################################################################################
#########################################################################################################


my $cfg = new Config::Simple('config.conf');

my $oradb;
#$oradb=oracle_connect($cfg->param('oracle_login'),$cfg->param('oracle_password'),$cfg->param('oracle_server'));
my $mydb=mysql_connect($cfg->param('mysql_login'),
			$cfg->param('mysql_password').'',
			$cfg->param('mysql_server'),
			$cfg->param('mysql_db'));

$| = 1;
use sigtrap 'handler' => \&sigtrap, 'HUP', 'INT','ABRT','QUIT','TERM'; # KILL handler

open(LOG,'>>log-debug.log');

my $time0= time();
# Read from STDIN
my $state=1; #permit all
while (<>) {

if ($DEBUG){open(F,"|/usr/bin/logger $_");close(F);}

my $time = time();

if ($time-$time0>1) # every 1 sec
    {	$state=mysql_query_state($mydb);
    }

my @input = split /[\"]/;

$input[1] =~ s/^\s+|\s+$//g; #username
$input[3] =~ s/^\s+|\s+$//g; #realm

#print LOG join(",", @input)."\n";

my @hash = (0,0);
my @cache=mysql_query_one($mydb,$input[1],$input[3], $cfg->param('cache_time'),$cfg->param('deauth_time'),$DEBUG);

if ($cache[0]==1) { # try search cache
    if ($DEBUG){open(F,"|/usr/bin/logger Found valid cache");close(F);}

    @hash=(1,$cache[1]);
    #print 'cached';
}
elsif ($cache[0]>10){ # if cache not found or expire try direct request
    if ($DEBUG){open(F,"|/usr/bin/logger Request to ORACLE");close(F);}

    @hash=oracle_query_one_test($oradb, $cfg->param('oracle_func'),$input[1],$input[3]);
    if ($hash[0]==1) { # update cache
	mysql_cache($mydb,$input[1],$hash[1],$hash[0]);
    }
} 

#print LOG join(", ", @hash)."\n";
print LOG gmtime().': LOGIN: '.$input[1].': RESULT: '.$hash[0]."\n";

if ($hash[0]==1){ # ALL OK
    #print LOG $input[0].'OK ha1="'.$hash[1]."\"\n";
    print  $input[0].'OK ha1="'.$hash[1]."\"\n";
    if ($DEBUG){open(F,"|/usr/bin/logger Return OK");close(F);}
    } 
else
    {	#NOT ok
    my $err='';
    if ($hash[0]==-3){$err='Invalid login';}
    if ($hash[0]==-2){$err='Password not set';}
    if ($hash[0]==-1){$err='Login must be lower case';}
    if ($hash[0]==0){$err='Invalid password';}
    if ($hash[0]==2){$err='Less 18 years';}
    
    print LOG $input[0].' ERR message="'.$err.'"'."\n";
    print $input[0].'ERR message="'.$err.'"'."\n";
    if ($DEBUG){open(F,"|/usr/bin/logger Return Error $err");close(F);}
    }
}
close(LOG);
$oradb->disconnect();
$mydb->disconnect();
