# paranoia Changelog

## 2.1.0 (2015-01-23)

### Major changes

* `#destroyed?` is no longer overridden. Use `#paranoia_destroyed?` for the existing behaviour. [Washington Luiz](https://github.com/huoxito)
* `#persisted?` is no longer overridden.
* ActiveRecord 4.0 no longer has `#destroy!` as an alias for `#really_destroy`.
* `#destroy` will now raise an exception if called on a readonly record.
* `#destroy` on a hard deleted record is now a successful noop.
* `#destroy` on a new record will set deleted_at (previously this raised an error)
* `#destroy` and `#delete` always return self when successful.

### Bug Fixes

* Calling `#destroy` twice will not hard-delete records. Use `#really_destroy` if this is desired.
* Fix errors on non-paranoid has_one dependent associations

## 2.0.5 (2015-01-22)

### Bug fixes

* Fix restoring polymorphic has_one relationships [#189](https://github.com/radar/paranoia/pull/189) [#174](https://github.com/radar/paranoia/issues/174) [Patrick Koperwas](https://github.com/PatKoperwas)
* Fix errors when restoring a model with a has_one against a non-paranoid model. [#168](https://github.com/radar/paranoia/pull/168) [Shreyas Agarwal](https://github.com/shreyas123)
* Fix rspec 2 compatibility [#197](https://github.com/radar/paranoia/pull/197) [Emil Sågfors](https://github.com/lime)
* Fix some deprecation warnings on rails 4.2 [Sergey Alekseev](https://github.com/sergey-alekseev)

## 2.0.4 (2014-12-02)

### Features
* Add paranoia_scope as named version of default_scope [#184](https://github.com/radar/paranoia/pull/184) [Jozsef Nyitrai](https://github.com/nyjt)


### Bug Fixes
* Fix initialization problems when missing table or no database connection [#186](https://github.com/radar/paranoia/issues/186)
* Fix broken restore of has_one associations [#185](https://github.com/radar/paranoia/issues/185) [#171](https://github.com/radar/paranoia/pull/171) [Martin Sereinig](https://github.com/srecnig)
