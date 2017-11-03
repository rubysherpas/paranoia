# paranoia Changelog

## 2.4.0

* [#423](https://github.com/rubysherpas/paranoia/pull/423) Add `paranoia_destroy` and `paranoia_delete` aliases

  [John Hawthorn (@jhawthorn)](https://github.com/jhawthorn)

* [#408](https://github.com/rubysherpas/paranoia/pull/408) Fix instance variable `@_disable_counter_cache` not initialized warning.

  [Akira Matsuda (@amatsuda)](https://github.com/amatsuda)

* [#412](https://github.com/rubysherpas/paranoia/pull/412) Fix `really_destroy!` behavior with `sentinel_value`

  [Steve Rice (@steverice)](https://github.com/steverice)

## 2.3.1

* [#397](https://github.com/rubysherpas/paranoia/pull/397) Bump active record max version to support 5.1 final

## 2.3.0 (2017-04-14)

* [#393](https://github.com/rubysherpas/paranoia/pull/393) Drop support for Rails 4.1 and begin supporting Rails 5.1.

  [Miklós Fazekas (@mfazekas)](https://github.com/mfazekas)

* [#391](https://github.com/rubysherpas/paranoia/pull/391) Use Contributor Covenant Version 1.4

  [Ben A. Morgan (@BenMorganIO)](https://github.com/BenMorganIO)

* [#390](https://github.com/rubysherpas/paranoia/pull/390) Fix counter cache with double destroy, really_destroy, and restore

  [Chris Oliver (@excid3)](https://github.com/excid3)

* [#389](https://github.com/rubysherpas/paranoia/pull/389) Added association not soft destroyed validator

  _Fixes [#380](https://github.com/rubysherpas/paranoia/issues/380)_

  [Edward Poot (@edwardmp)](https://github.com/edwardmp)

* [#383](https://github.com/rubysherpas/paranoia/pull/383) Add recovery window feature

  _Fixes [#359](https://github.com/rubysherpas/paranoia/issues/359)_

  [Andrzej Piątyszek (@konto-andrzeja)](https://github.com/konto-andrzeja)


## 2.2.1 (2017-02-15)

* [#371](https://github.com/rubysherpas/paranoia/pull/371) Use ActiveSupport.on_load to correctly re-open ActiveRecord::Base

  _Fixes [#335](https://github.com/rubysherpas/paranoia/issues/335) and [#381](https://github.com/rubysherpas/paranoia/issues/381)._

  [Iaan Krynauw (@iaankrynauw)](https://github.com/iaankrynauw)

* [#377](https://github.com/rubysherpas/paranoia/pull/377) Touch record on paranoia-destroy.

  _Fixes [#296](https://github.com/rubysherpas/paranoia/issues/296)._

  [René (@rbr)](https://github.com/rbr)

* [#379](https://github.com/rubysherpas/paranoia/pull/379) Fixes a problem of ambiguous table names when using only_deleted method.

  _Fixes [#26](https://github.com/rubysherpas/paranoia/issues/26) and [#27](https://github.com/rubysherpas/paranoia/pull/27)._

  [Thomas Romera (@Erowlin)](https://github.com/Erowlin)

## 2.2.0 (2016-10-21)

* Ruby 2.0 or greater is required
* Rails 5.0.0.beta1.1 support [@pigeonworks](https://github.com/pigeonworks) [@halostatue](https://github.com/halostatue) and [@gagalago](https://github.com/gagalago)
* Previously `#really_destroyed?` may have been defined on non-paranoid models, it is now only available on paranoid models, use regular `#destroyed?` instead.

## 2.1.5 (2016-01-06)

* Ruby 2.3 support

## 2.1.4

## 2.1.3

## 2.1.2

## 2.1.1

## 2.1.0 (2015-01-23)

### Major changes

* `#destroyed?` is no longer overridden. Use `#paranoia_destroyed?` for the existing behaviour. [Washington Luiz](https://github.com/huoxito)
* `#persisted?` is no longer overridden.
* ActiveRecord 4.0 no longer has `#destroy!` as an alias for `#really_destroy!`.
* `#destroy` will now raise an exception if called on a readonly record.
* `#destroy` on a hard deleted record is now a successful noop.
* `#destroy` on a new record will set deleted_at (previously this raised an error)
* `#destroy` and `#delete` always return self when successful.

### Bug Fixes

* Calling `#destroy` twice will not hard-delete records. Use `#really_destroy!` if this is desired.
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
