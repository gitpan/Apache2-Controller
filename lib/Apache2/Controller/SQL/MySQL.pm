package Apache2::Controller::SQL::MySQL;

=head1 NAME

Apache2::Controller::SQL::MySQL - useful database methods for MySQL

=head1 SYNOPSIS

 package MyApp::C::Foo;
 use base qw( 
     Apache2::Controller 
     Apache2::Controller::MySQL
 );
 # ...

=head1 METHODS

=head2 insert_hash( \%hashref )

Insert data into the database.

 # insert_hash()
 # http://myapp.xyz/foo?ship=enterprise&captain=kirk&sci=spock&med=mccoy
 sub register_crew {
     my ($self) = @_; 
     my $crew = $self->fields(qw( captain sci med ));
     $self->insert_hash({
         table   => 'crew',
         data    => $crew,
     });
     $self->print("Warp factor 5, engage.\n");
     return Apache2::Const::HTTP_OK;
 }

Hashref argument supports these fields:

=over 4

=item * table

The SQL table to insert into.

=item * data

The hash ref of field data to insert.

=item * on_dup_sql

Optional string of SQL for after 'ON DUPLICATE KEY UPDATE'.
This MySQL SQL extension be used if this param is absent.

=item * on_dup_bind

Array ref of bind values for ?'s in on_dup_sql.

=back

=cut

sub insert_hash {
    my ($self, $p) = @_;

    my ($table, $data, $on_dup_sql, $on_dup_bind) = @{$p}{qw(
        table  data  on_dup_sql  on_dup_bind
    )};

    my @bind = values %{$data};

    my $sql 
        = "INSERT INTO $table SET\n"
        . join(",\n", map {"    $_ = ".(ref $_ ? $_ : '?')} keys %{$data});

    if ($on_dup_sql) {
        $sql .= "\nON DUPLICATE KEY UPDATE\n$on_dup_sql\n";
        push @bind, @{$on_dup_bind} if $on_dup_bind;
    }

    my $dbh = $self->{dbh};
    my $id;
    eval {
        DEBUG("preparing handle for sql:\n$sql\n---\n");
        my $sth = $dbh->prepare_cached($sql);
        $sth->execute(@bind);
        ($id) = $dbh->selectrow_array(q{ SELECT LAST_INSERT_ID() });
    };
    if ($EVAL_ERROR) {
        Dolph::X->throw(
            message => "database error: $EVAL_ERROR",
            dump => {
                sql => $sql,
                bind => \@bind,
            },
        );
    }
    return $id;
}




1;

