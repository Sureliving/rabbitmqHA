package main

import (
	"fmt"
	"log"
	"os"
	"time"

	"github.com/streadway/amqp"
)

func failOnError(err error, msg string) {
	if err != nil {
		log.Fatalf("%s: %s", msg, err)
	}
}

func main() {
	rabbitURL := os.Getenv("RABBITMQ_URL")
	if rabbitURL == "" {
		log.Fatalf("RABBITMQ_URL is not set")
	}

	conn, err := amqp.Dial(rabbitURL)
	failOnError(err, "Failed to connect to RabbitMQ")
	defer conn.Close()

	ch, err := conn.Channel()
	failOnError(err, "Failed to open a channel")
	defer ch.Close()

	queueName := "testhighavailability"
	exchangeName := "federation.exchange"

	msgs, err := ch.Consume(
		queueName,
		"",
		false,
		false,
		false,
		false,
		amqp.Table{"x-queue-type": "quorum"},
	)
	failOnError(err, "Failed to register a consumer")

	go func() {
		var messageBodies string
		count := 0

		for msg := range msgs {
			messageBodies += string(msg.Body) + " "
			count++
			if count == 100 {
				ch.QueuePurge(queueName, false)
				break
			}
		}

		log.Printf("Messages: %s", messageBodies)
	}()

	oddNumber := 1

	for {
		err = ch.Publish(
			exchangeName,
			"",
			false,
			false,
			amqp.Publishing{
				ContentType: "text/plain",
				Body:        []byte(fmt.Sprintf("%d", oddNumber)),
			})
		failOnError(err, "Failed to publish a message")

		oddNumber += 2
		if oddNumber > 100 {
			oddNumber = 2
		}

		time.Sleep(60 * time.Second)
	}
}
