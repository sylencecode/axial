#!/usr/bin/env ruby

$LOAD_PATH.unshift('../lib')
require 'axial/mask_utils'
require 'axial/axnet/user'
require 'axial/axnet/user_list'

@user_list = Axial::Axnet::UserList.new

user = Axial::Axnet::User.new
user.name = 'x-jester'
user.pretty_name = 'X-Jester'
user.role = 'director'
user.masks.push('*!*@cheese.org')
@user_list.add(user)

user = Axial::Axnet::User.new
user.name = 'tom'
user.pretty_name = 'tom'
user.masks.push('*!*tom@*.tom.org')
user.role = 'director'

@user_list.add(user)

def get_users_from_mask(in_mask)
  possible_users = []
  left_mask = Axial::MaskUtils.ensure_wildcard(in_mask)
  left_regexp = Axial::MaskUtils.get_mask_regexp(in_mask)
  @user_list.all_users.each do |user|
    user.masks.each do |right_mask|
      right_regexp = Axial::MaskUtils.get_mask_regexp(right_mask)
      if (right_regexp.match(left_mask))
        possible_users.push(user)
      elsif (left_regexp.match(right_mask))
        possible_users.push(user)
      end
    end
  end
  return possible_users
end

joes = get_users_from_mask('foo!xj@cheese.org')
puts joes.inspect
joes = get_users_from_mask('foo!tom@foo.tom.org')
puts joes.inspect
