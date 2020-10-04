//
//  GameScene.swift
//  tutorialGame1
//
//  Created by Ethan Nerney on 10/3/20.
//  Copyright © 2020 Ethan Nerney. All rights reserved.
//

import SpriteKit
import GameplayKit
import CoreMotion

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    // Starfield is the particle effect (SKEmitter) node that represents the background of the game
    var starfield: SKEmitterNode!
    // Player is the Sprite node that the user controls
    var player:SKSpriteNode!

    // the label that shows player score
    var scoreLabel: SKLabelNode!
    // the score, with a closure that updates the scoreLabel every time score changes
    var score: Int = 0 {
        didSet {
            scoreLabel.text = "Score: \(score)"
        }
    }
    
    var gameTimer: Timer!
    
    // array of image names that correspond to the different types of aliens
    var possibleAliens = ["alien", "alien2", "alien3"]
    
    // This stuff has to do with collision detection
    let alienCategory:UInt32 = 0x1 << 1
    let photonTorpedoCategory:UInt32 = 0x1 << 0
    
    
    let motionManager = CMMotionManager()
    
    
    // this function is called at the outset
    override func didMove(to view: SKView) {
        // assign starfield, put it in the top left corner, and advance the simulation ahead so that the stars don't have to fill in
        starfield = SKEmitterNode(fileNamed: "Starfield")
        starfield.position = CGPoint(x:0, y:self.frame.size.height/2)
        starfield.advanceSimulationTime(10)
        self.addChild(starfield)
        // send starfield to the back
        starfield.zPosition = -1
        
        // create the player and place it at the bottom of the screen
        player = SKSpriteNode(imageNamed: "shuttle")
        player.position = CGPoint(x: 0, y: -(self.frame.height/2) + player.size.height)
        self.addChild(player)
        
        // get rid of gravity
        self.physicsWorld.gravity = CGVector(dx: 0, dy: 0)
        self.physicsWorld.contactDelegate = self
        
        // create the score label and place it in the top left corner
        scoreLabel = SKLabelNode(text: "Score: 0")
        scoreLabel.position = CGPoint(x: -200, y: 500)
        scoreLabel.fontColor = UIColor.white
        score = 0
        self.addChild(scoreLabel)

        // schedule the timer to repeatedly add an alien
        gameTimer = Timer.scheduledTimer(timeInterval: 0.75, target: self, selector: #selector(addAlien),  userInfo: nil, repeats: true)
    }
    
    @objc func addAlien() {
        // shuffle the possibleAliens array
        possibleAliens = GKRandomSource.sharedRandom().arrayByShufflingObjects(in: possibleAliens) as! [String]
        // draw the image name from the top of the shuffled array
        let alien = SKSpriteNode(imageNamed:possibleAliens[0])
        // get a new random int from the distribution and set it as the position
        let randomAlienPosition = GKRandomDistribution(lowestValue: Int(-self.frame.width/2), highestValue: Int(self.frame.width/2))
        let position = CGFloat(randomAlienPosition.nextInt())
        alien.position = CGPoint(x:position, y: self.frame.size.height/2 + alien.size.height)
        
        // give alien a physicsBody, make sure it's dynamic, and set it to handle collisions
        alien.physicsBody = SKPhysicsBody(rectangleOf: alien.size)
        alien.physicsBody?.isDynamic = true
        alien.physicsBody?.categoryBitMask = alienCategory
        alien.physicsBody?.contactTestBitMask = photonTorpedoCategory
        alien.physicsBody?.collisionBitMask = 0
        
        // add the alien
        self.addChild(alien)
        
        // create a sequence of actions for the alien to perform
        let animationDuration: TimeInterval = 6
        var actionArray  = [SKAction]()
        // move directly downwards to the bottom of the screen in the span of animationDuration (6 seconds)
        actionArray.append(SKAction.move(to: CGPoint(x: position, y: -(self.frame.height/2)-alien.size.height), duration: animationDuration))
        // destroy alien once it's off the screen
        actionArray.append(SKAction.removeFromParent())
        // run the sequence
        alien.run(SKAction.sequence(actionArray))
    }
    
    // a function that gets called when someone touches the screen and then stops
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?)  {
        fireTorpedo()
    }
    
    
    func fireTorpedo() {
        // play the sound effect, but don't wait for it to finish before executing anything else
        self.run(SKAction.playSoundFileNamed("torpedo.mp3", waitForCompletion: false))
        
        // create the torpedo from the image, and place it directly in front of the player
        let torpedoNode = SKSpriteNode(imageNamed: "torpedo")
        torpedoNode.position = player.position
        torpedoNode.position.y += 5
        
        // give torpedoNode a physics body, and making it dynamic
        torpedoNode.physicsBody = SKPhysicsBody(circleOfRadius: torpedoNode.size.width / 2)
        torpedoNode.physicsBody?.isDynamic = true
        // do the collision stuff, including making it use precise collision detection
        torpedoNode.physicsBody?.categoryBitMask = photonTorpedoCategory
        torpedoNode.physicsBody?.contactTestBitMask = alienCategory
        torpedoNode.physicsBody?.collisionBitMask = 0
        torpedoNode.physicsBody?.usesPreciseCollisionDetection = true
        // add torpedo to game
        self.addChild(torpedoNode)
        
        // animation stuff, move directly vertical
        let animationDuration: TimeInterval = 1
        var actionArray  = [SKAction]()
        actionArray.append(SKAction.move(to: CGPoint(x: player.position.x, y:self.frame.size.height + 10), duration: animationDuration))
        actionArray.append(SKAction.removeFromParent())
        torpedoNode.run(SKAction.sequence(actionArray))
        
    }
    
    // called when a collision happens
    func didBegin(_ contact: SKPhysicsContact) {
        var firstBody: SKPhysicsBody
        var secondBody: SKPhysicsBody
        
        if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
            firstBody = contact.bodyA
            secondBody = contact.bodyB
        } else {
            firstBody = contact.bodyB
            secondBody = contact.bodyA
        }
        
        if (firstBody.categoryBitMask & photonTorpedoCategory) != 0 && (secondBody.categoryBitMask & alienCategory) != 0  {
            didColide(torpedo: firstBody.node as! SKSpriteNode, alien: secondBody.node as! SKSpriteNode)
        }
        
    }
    
    // called when a torpedo and alien collide
    func didColide(torpedo:SKSpriteNode, alien:SKSpriteNode) {
        // create explosion at the alien's position
        let explosion = SKEmitterNode(fileNamed: "Explosion")!
        explosion.position = alien.position
        self.addChild(explosion)
        
        // play the sound effect, without waiting for it to stop
        self.run(SKAction.playSoundFileNamed("explosion.mp3", waitForCompletion: false))
        
        // destroy torpedo and alien instantly
        torpedo.removeFromParent()
        alien.removeFromParent()
        
        // destroy explosion after 2 seconds
        self.run(SKAction.wait(forDuration: 2), completion: {explosion.removeFromParent()})
        
        score += 5
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
    }
}
