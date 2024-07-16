@IsTest
private class ChatterFollowersTest {
    
    @IsTest static void test_method_one() {
        List<Case> Cases = [SELECT Id FROM Case];
        List<User> Users = ChatterFollowers.getFollowers(Cases[0].Id);
        System.assertEquals(Users.size(), 1);
        
    }
    
    @TestSetup static void testSetupCoreObjects() {
        Case c = new Case();
        c.status = 'New';
        c.Subject = 'your software sucks';
        insert c;

        EntitySubscription ES = new EntitySubscription();
        ES.SubscriberID = UserInfo.getUserId();
        ES.ParentId = c.Id;
        insert ES;        
    }
    
}