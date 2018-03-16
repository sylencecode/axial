require 'singleton'

#
#                    
#  DB constant -> users/nicks/masks/seens/etc
#
#  invocation models need to lock in a synchronize loop
#                    
#                    
#                    
#                |   
#                |--- Database constant DB
#                |   :
#                |--- Config parser (from Bot.config =)
#                | 
#                |  
# Bot singleton -|--- Server Connection Handler ->   call dispatchers
#                                   #            
#                                   #              .--- Chat writer - needs to able to blocked... so, mutex.wait after deq?
#                                   #             |   
#                                   #             |--- Raw writer enq (should block chat writer)... so, conditionvariable lock?
#                                   #             |
#                                   #             `--- Ping writer enq (should block raw writer and chat writer)... so, conditionvariable lock?
#                |
#                |
#                |--- Dispatcher list  --> on_303, on_256, on_etc.. needs to block msg/raw writers destined for channel
#                |
#                |
#                |--- Channel list --- channel dispatchers need to lock these until sync'd
#                |
#                |
#                |                 .---> messages -> calls addon list
#                |                 |
#                |--- Handler list |---> IRC events -> calls core handlers list
#                |                 |
#                |                 `---> 
#                |
#                |
#                |--- Addon list 
#                | 
#                |--- Libraries like API and handlers (how to handle requires in these cases?)
#                | 
#                | 
#                | 
#                | 
#                `---- 
#                     
#                     
#                     
